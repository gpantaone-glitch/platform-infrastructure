############################################
# Read EKS Remote State
############################################

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "tf-state-org-platform"
    key    = "dev/02-eks/terraform.tfstate"
    region = "us-east-1"
  }
}

############################################
# EKS Auth
############################################

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

############################################
# Kubernetes Provider
############################################

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

############################################
# Allow Terraform Deployer Role to Access EKS
############################################

resource "aws_eks_access_entry" "terraform_deployer" {
  cluster_name  = data.terraform_remote_state.eks.outputs.cluster_name
  principal_arn = "arn:aws:iam::317976464242:role/terraform-deployer-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_deployer_admin" {
  cluster_name  = data.terraform_remote_state.eks.outputs.cluster_name
  principal_arn = aws_eks_access_entry.terraform_deployer.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

############################################
# Helm Provider
############################################

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

############################################
# IAM Role for ALB Controller (IRSA)
############################################

# ---- Locals used by the IAM role (computed OIDC subject key + policy object) ----
locals {
  oidc_sub = "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:sub"

  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks.outputs.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            (local.oidc_sub) = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  }
}

# ---- IAM Role for ALB Controller (IRSA) ----
resource "aws_iam_role" "alb_controller" {
  name = "org-dev-alb-controller"

  assume_role_policy = jsonencode(local.assume_role_policy)
}

############################################
# Attach AWS ALB Controller Policy
############################################

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::317976464242:policy/AWSLoadBalancerControllerIAMPolicy"
}

############################################
# Kubernetes Service Account
############################################

resource "kubernetes_service_account_v1" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
depends_on = [
    aws_eks_access_policy_association.terraform_deployer_admin
  ]
}

############################################
# Install AWS Load Balancer Controller
############################################

resource "helm_release" "alb" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set = [
	{ 
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_name
},
{
    name  = "serviceAccount.create"
    value = "false"
},
{
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
]
}

##########################################
# Install ArgoCD
##########################################

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  set = [ {
    name  = "server.service.type"
    value = "LoadBalancer"
  },
{
	name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
  	value = "internet-facing"
}
 ]
}
