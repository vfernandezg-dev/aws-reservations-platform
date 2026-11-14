# Partial backend configuration. The bucket comes from the bootstrap stack and
# the per-environment settings from environments/<env>.s3.tfbackend:
#
#   terraform init -reconfigure \
#     -backend-config=environments/dev.s3.tfbackend \
#     -backend-config="bucket=<state-bucket>"
#
# Locking uses S3 conditional writes (use_lockfile), no DynamoDB table.
terraform {
  backend "s3" {}
}
