data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
  	bucket = "tf-state-org-platform"
	key    = "dev/01-network/terraform.tfstate"
    	region = "us-east-1"
	}
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "org-dev-eks"
  cluster_version = "1.29"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_eks_access_entry" "dev_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::317976464242:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DevAdmin_06a57f961788697a"
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "platform_ci" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::078591672268:role/PlatformCIExecutionRole"

  type = "STANDARD"
}

resource "aws_eks_access_policy_association" "dev_admin_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.dev_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "platformci_admin_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.platform_ci.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
}

##################################
resource "aws_eks_access_entry" "terraform_deployer" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::317976464242:role/terraform-deployer-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_deployer_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.terraform_deployer.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

####################################

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}
