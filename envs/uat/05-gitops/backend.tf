terraform {
  backend "s3" {
    bucket = "tf-state-org-platform"
    key    = "uat/05-gitops/terraform.tfstate"
    region = "us-east-1"
  }
}
