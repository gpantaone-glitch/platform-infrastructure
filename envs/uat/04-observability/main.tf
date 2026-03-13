data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "tf-state-org-platform"
    key    = "uat/03-platform/terraform.tfstate"
    region = "us-east-1"
  }
}
