data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  region = var.region
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

data "aws_iam_policy_document" "this" {
  #checkov:skip=CKV_AWS_109:Key policy: "Resource = *" refers to this key only; root statement delegates access to IAM policies (AWS default).
  #checkov:skip=CKV_AWS_111:Key policy: "Resource = *" refers to this key only; service principals are constrained by conditions.
  #checkov:skip=CKV_AWS_356:Key policies must use "*" as resource (it means the key the policy is attached to).
  # Key administration and IAM-based usage (RDS, Secrets Manager and ECS roles
  # are authorized through their own IAM policies).
  statement {
    sid       = "EnableIamPolicies"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs encrypts log groups of this account and region only.
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  # CloudWatch alarms publish to SNS topics encrypted with this key.
  statement {
    sid       = "AllowCloudWatchAlarmsToEncryptedSns"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  region                  = var.region
  description             = "Customer managed key for ${var.name} (logs, database, secrets, notifications)"
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.this.json

  tags = {
    Name = var.name
  }
}

resource "aws_kms_alias" "this" {
  region        = var.region
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
