terraform {
  backend "s3" {
    bucket = "tf-state-org-platform"
    key    = "dev/05-gitops/terraform.tfstate"
    region = "us-east-1"
  }
}
