terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }

  # The bootstrap stack creates the remote-state bucket, so it starts with
  # local state. After the first apply you can migrate it into the bucket:
  #   terraform init -migrate-state \
  #     -backend-config="bucket=<state_bucket_name>" -backend-config="key=bootstrap/terraform.tfstate" \
  #     -backend-config="region=us-east-1" -backend-config="use_lockfile=true"
  # (uncomment the block below first)
  #
  # backend "s3" {}
}
