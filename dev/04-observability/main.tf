data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "tf-state-org-dev-enterpause"
    key    = "dev/02-eks/terraform.tfstate"
    region = "us-east-1"
  }
}
