data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "tf-state-org-platform"
    key    = "dev/04-observability/terraform.tfstate"
    region = "us-east-1"
  }
}
