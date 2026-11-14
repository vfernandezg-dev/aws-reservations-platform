data "aws_region" "current" {}

locals {
  hosted_ui_enabled = length(var.callback_urls) > 0
}

# Cognito domain prefixes are global per region and may not contain "aws",
# "amazon" or "cognito": add a random suffix for uniqueness.
resource "random_string" "domain_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_cognito_user_pool" "this" {
  name                = var.name
  user_pool_tier      = "ESSENTIALS"
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    password_history_size            = 5
    temporary_password_validity_days = 3
  }

  mfa_configuration = var.mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "OFF" ? [] : [1]

    content {
      enabled = true
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = !var.allow_self_registration
  }

  # Cognito's built-in email sender is fine for demos; switch to Amazon SES
  # (email_sending_account = "DEVELOPER") for production volumes.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Name = var.name
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain                = "${var.name}-${random_string.domain_suffix.result}"
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2
}

# Public client for the single-page app: no client secret, SRP sign-in and
# authorization-code flow (PKCE) only. Implicit flow is intentionally absent.
resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.name}-spa"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.access_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  allowed_oauth_flows_user_pool_client = local.hosted_ui_enabled
  allowed_oauth_flows                  = local.hosted_ui_enabled ? ["code"] : null
  allowed_oauth_scopes                 = local.hosted_ui_enabled ? ["openid", "email", "profile"] : null
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = local.hosted_ui_enabled ? var.callback_urls : null
  logout_urls                          = local.hosted_ui_enabled ? var.logout_urls : null
}

# Managed Login (v2) with Cognito's default branding.
resource "aws_cognito_managed_login_branding" "spa" {
  count = local.hosted_ui_enabled ? 1 : 0

  user_pool_id                = aws_cognito_user_pool.this.id
  client_id                   = aws_cognito_user_pool_client.spa.id
  use_cognito_provided_values = true
}
