provider "aws" {
  region = var.aws_region

  # Applied to every taggable resource. Modules only add a Name tag.
  # Global/edge resources (CloudFront, WAF) are placed in us-east-1 with the
  # per-resource `region` argument (AWS provider v6) instead of a provider alias.
  default_tags {
    tags = local.default_tags
  }
}
