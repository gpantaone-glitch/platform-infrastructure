provider "aws" {
  region = "us-east-1"

  assume_role {
	role_arn = "arn:aws:iam::997208471891:role/terraform-deployer-role"    
  }
}
