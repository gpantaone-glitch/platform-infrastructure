terraform {
  backend "s3" {
    bucket         = "tf-state-org-platform"
    key            = "dev/04-observability/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock-org-platform"
    encrypt        = true
    assume_role = {
    role_arn = "arn:aws:iam::317976464242:role/terraform-deployer-role" 
    }
    }
}
