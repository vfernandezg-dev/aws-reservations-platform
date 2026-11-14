data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name}-static-${data.aws_caller_identity.current.account_id}"

  site_files = var.upload_sample_site ? {
    "index.html" = {
      content_type = "text/html; charset=utf-8"
      content = templatefile("${path.module}/templates/index.html.tftpl", {
        title       = var.site_title
        environment = var.environment
      })
    }
  } : {}
}

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is not required for this data (multi-region DR is on the roadmap).
  #checkov:skip=CKV2_AWS_62:No consumer for S3 event notifications.
  #checkov:skip=CKV_AWS_18:Every read goes through CloudFront, whose access logs are delivered to the log bucket.
  #checkov:skip=CKV_AWS_145:Public web assets; SSE-S3 lets CloudFront OAC read them without a KMS key policy.
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3: CloudFront Origin Access Control can read it without a customer
# managed KMS key policy. Content is public through the CDN anyway.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_object" "site" {
  for_each = local.site_files

  bucket        = aws_s3_bucket.this.id
  key           = each.key
  content       = each.value.content
  content_type  = each.value.content_type
  cache_control = "public, max-age=300"
  etag          = md5(each.value.content)
}
