data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "tf-state-org-platform"
    key    = "uat/02-eks/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}
