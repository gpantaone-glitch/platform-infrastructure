provider "aws" {
  region = "us-east-1"

  assume_role {
	role_arn = "arn:aws:iam::317976464242:role/terraform-deployer-role"    
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
