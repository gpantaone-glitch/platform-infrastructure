terraform {
  backend "s3" {
    bucket         = "tf-state-org-platform"
    key            = "dev/01-network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock-org-platform"
    encrypt        = true
    assume_role = {
    role_arn       = "arn:aws:iam::078591672268:role/PlatformStateAccessRole"
    }
    }
}
