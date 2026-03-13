terraform {
  backend "s3" {
    bucket         = "tf-state-org-platform"
    key            = "uat/02-eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock-org-platform"
    encrypt        = true
    }
}
