#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup_vpc.sh <vpc-id> [profile] [region]
VPC_ID="${1:-}"
PROFILE="${2:-dev}"
REGION="${3:-us-east-1}"

if [ -z "$VPC_ID" ]; then
  echo "ERROR: VPC_ID is required as first argument"
  exit 2
fi

echo "Cleanup for VPC: $VPC_ID (profile=$PROFILE region=$REGION)"
echo

aws_args=(--profile "$PROFILE" --region "$REGION")

# helper to run aws and return empty string on no-result
aws_query() {
  aws "${aws_args[@]}" "$@" 2>/dev/null || echo ""
}

# 1) Delete ELBs (ALB/NLB)
echo "Deleting ELBv2 load balancers in VPC..."
LBS=$(aws "${aws_args[@]}" elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text || true)
if [ -n "$LBS" ]; then
  for lb in $LBS; do
    echo "Deleting LB $lb"
    aws "${aws_args[@]}" elbv2 delete-load-balancer --load-balancer-arn "$lb" || echo "warn: delete-lb failed for $lb"
  done
else
  echo "No ELBv2 load balancers found."
fi
echo

# 2) Delete target groups (best effort)
echo "Deleting target groups referencing this VPC (best effort)..."
TGS=$(aws "${aws_args[@]}" elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupArn, '')].TargetGroupArn" --output text || true)
# Filter target groups by describing attributes is expensive; skip aggressive deletion unless explicit
echo "Skipping aggressive target group deletion (handled by LB deletion)."
echo

# 3) Delete VPC endpoints
echo "Deleting VPC endpoints..."
EP_IDS=$(aws "${aws_args[@]}" ec2 describe-vpc-endpoints --filters Name=vpc-id,Values="$VPC_ID" --query 'VpcEndpoints[*].VpcEndpointId' --output text || true)
if [ -n "$EP_IDS" ]; then
  for ep in $EP_IDS; do
    echo "Deleting VPC endpoint $ep"
    aws "${aws_args[@]}" ec2 delete-vpc-endpoints --vpc-endpoint-ids "$ep" || echo "warn: delete-vpc-endpoint $ep failed"
  done
else
  echo "No VPC endpoints found."
fi
echo

# 4) Delete NAT gateways
echo "Deleting NAT Gateways..."
NATS=$(aws "${aws_args[@]}" ec2 describe-nat-gateways --filter Name=vpc-id,Values="$VPC_ID" --query 'NatGateways[*].NatGatewayId' --output text || true)
if [ -n "$NATS" ]; then
  for nat in $NATS; do
    echo "Deleting NAT gateway $nat"
    aws "${aws_args[@]}" ec2 delete-nat-gateway --nat-gateway-id "$nat" || echo "warn: delete-nat-gateway $nat failed"
  done
else
  echo "No NAT gateways."
fi
echo

# 5) Detach and delete internet gateways
echo "Detaching and deleting Internet Gateways..."
IGWS=$(aws "${aws_args[@]}" ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$VPC_ID" --query 'InternetGateways[*].InternetGatewayId' --output text || true)
if [ -n "$IGWS" ]; then
  for igw in $IGWS; do
    echo "Detaching IGW $igw"
    aws "${aws_args[@]}" ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" || echo "warn: detach-igw $igw failed"
    echo "Deleting IGW $igw"
    aws "${aws_args[@]}" ec2 delete-internet-gateway --internet-gateway-id "$igw" || echo "warn: delete-igw $igw failed"
  done
else
  echo "No attached IGWs."
fi
echo

# 6) Delete non-default security groups
echo "Deleting non-default security groups..."
SGS_JSON=$(aws "${aws_args[@]}" ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" --query 'SecurityGroups' --output json || echo "[]")
SG_IDS=$(echo "$SGS_JSON" | python3 -c "import sys, json; a=json.load(sys.stdin); print(' '.join([x['GroupId'] for x in a if x.get('GroupName')!='default']))" 2>/dev/null || true)
if [ -n "$SG_IDS" ]; then
  for sg in $SG_IDS; do
    echo "Attempting delete security-group $sg"
    aws "${aws_args[@]}" ec2 delete-security-group --group-id "$sg" 2>/dev/null || echo "warn: cannot delete $sg (in use?)"
  done
else
  echo "No non-default security groups to delete."
fi
echo

# 7) Delete non-default network ACLs
echo "Deleting non-default Network ACLs..."
NACLS_JSON=$(aws "${aws_args[@]}" ec2 describe-network-acls --filters Name=vpc-id,Values="$VPC_ID" --query 'NetworkAcls' --output json || echo "[]")
NACL_IDS=$(echo "$NACLS_JSON" | python3 -c "import sys,json; a=json.load(sys.stdin); print(' '.join([x['NetworkAclId'] for x in a if not x.get('IsDefault')]))" 2>/dev/null || true)
if [ -n "$NACL_IDS" ]; then
  for acl in $NACL_IDS; do
    echo "Deleting NACL $acl"
    aws "${aws_args[@]}" ec2 delete-network-acl --network-acl-id "$acl" || echo "warn: delete-nacl $acl failed"
  done
else
  echo "No non-default NACLs."
fi
echo

# 8) Delete custom route tables (non-main)
echo "Deleting non-main route table associations and non-main route tables..."
RT_ASSOC_IDS=$(aws "${aws_args[@]}" ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" --query 'RouteTables[*].Associations[*].RouteTableAssociationId' --output text || true)
# iterate associations; disassociate only those that are not main
RT_JSON=$(aws "${aws_args[@]}" ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" --query 'RouteTables' --output json || echo "[]")
python3 - <<PY
import sys,json,subprocess
rt=json.load(sys.stdin)
for r in rt:
    for a in r.get('Associations',[]):
        if not a.get('Main'):
            rid=a.get('RouteTableAssociationId')
            if rid:
                print("DISASSOC:"+rid)
for r in rt:
    if not any(a.get('Main') for a in r.get('Associations',[])):
        rid=r.get('RouteTableId')
        if rid:
            print("DELETE_RT:"+rid)
PY < <(echo "$RT_JSON") | while read line; do
  case "$line" in
    DISASSOC:*)
      assoc=${line#DISASSOC:}
      echo "Disassociating $assoc"
      aws "${aws_args[@]}" ec2 disassociate-route-table --association-id "$assoc" || echo "warn disassoc $assoc"
      ;;
    DELETE_RT:*)
      rtid=${line#DELETE_RT:}
      echo "Deleting route table $rtid"
      aws "${aws_args[@]}" ec2 delete-route-table --route-table-id "$rtid" || echo "warn delete-rt $rtid"
      ;;
  esac
done
echo

# 9) Delete subnets (if still present)
echo "Deleting subnets..."
SUBNETS=$(aws "${aws_args[@]}" ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --query 'Subnets[*].SubnetId' --output text || true)
if [ -n "$SUBNETS" ]; then
  for s in $SUBNETS; do
    echo "Deleting subnet $s"
    aws "${aws_args[@]}" ec2 delete-subnet --subnet-id "$s" || echo "warn: delete-subnet $s failed"
  done
else
  echo "No subnets."
fi
echo

# 10) Wait for ENIs and LBs to clear (up to 10 minutes)
echo "Waiting for ENIs and LBs to clear (up to 10 minutes)..."
for i in {1..60}; do
  ENIS=$(aws "${aws_args[@]}" ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text || true)
  LBS_NOW=$(aws "${aws_args[@]}" elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text || true)
  if [ -z "$ENIS" ] && [ -z "$LBS_NOW" ]; then
    echo "No ENIs or LBs left."
    break
  fi
  echo "Still present (ENIs: ${ENIS:-none}, LBs: ${LBS_NOW:-none}) - attempt $i/60"
  sleep 10
done

# 11) Final attempt to delete VPC (will return precise dependency violation if any)
echo "Attempting final delete-vpc (will show exact blocking resource if it fails):"
set +e
aws "${aws_args[@]}" ec2 delete-vpc --vpc-id "$VPC_ID"
RC=$?
set -e
if [ $RC -eq 0 ]; then
  echo "delete-vpc accepted."
else
  echo "delete-vpc failed. Run the same delete-vpc command again to see the DependencyViolation message (it will list the blocking resource)."
fi

echo "DONE"
