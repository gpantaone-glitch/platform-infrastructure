provider "aws" {
  region = "us-east-1"

  assume_role {
	role_arn = "arn:aws:iam::317976464242:role/terraform-deployer-role"    
  }
}
