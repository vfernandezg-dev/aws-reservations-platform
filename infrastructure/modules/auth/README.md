# Authentication (Amazon Cognito)

Cognito user pool and a public SPA client used by the API Gateway JWT authorizer.

## Design

- Essentials feature plan, email as username, a strong password policy with history, optional or enforced TOTP MFA, account recovery by verified email, and deletion protection.
- Public client (no secret) limited to SRP sign-in and refresh tokens. The OAuth authorization-code flow (PKCE) is enabled only when callback URLs are provided; the deprecated implicit flow is never allowed.
- Managed Login (v2) domain with Cognito's default branding.

## Usage

```hcl
module "auth" {
  source = "./modules/auth"

  name              = "reservations-prod"
  mfa_configuration = "OPTIONAL"
  callback_urls     = ["https://d111111abcdef8.cloudfront.net/"]
  logout_urls       = ["https://d111111abcdef8.cloudfront.net/"]
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.70 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.70 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.7 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cognito_managed_login_branding.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_managed_login_branding) | resource |
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.spa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [random_string.domain_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_access_token_validity_minutes"></a> [access\_token\_validity\_minutes](#input\_access\_token\_validity\_minutes) | Lifetime of access and ID tokens in minutes. | `number` | `60` | no |
| <a name="input_allow_self_registration"></a> [allow\_self\_registration](#input\_allow\_self\_registration) | Allow users to sign themselves up. When false, only administrators can create users. | `bool` | `true` | no |
| <a name="input_callback_urls"></a> [callback\_urls](#input\_callback\_urls) | OAuth callback URLs for the Managed Login (hosted UI). Empty list disables the OAuth code flow. | `list(string)` | `[]` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protect the user pool from deletion. | `bool` | `true` | no |
| <a name="input_logout_urls"></a> [logout\_urls](#input\_logout\_urls) | Allowed sign-out redirect URLs. | `list(string)` | `[]` | no |
| <a name="input_mfa_configuration"></a> [mfa\_configuration](#input\_mfa\_configuration) | MFA enforcement: OFF, OPTIONAL (users may enrol TOTP) or ON (required). | `string` | `"OPTIONAL"` | no |
| <a name="input_password_minimum_length"></a> [password\_minimum\_length](#input\_password\_minimum\_length) | Minimum password length. | `number` | `12` | no |
| <a name="input_refresh_token_validity_days"></a> [refresh\_token\_validity\_days](#input\_refresh\_token\_validity\_days) | Lifetime of refresh tokens in days. | `number` | `30` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_id"></a> [client\_id](#output\_client\_id) | ID of the SPA app client (JWT audience). |
| <a name="output_domain"></a> [domain](#output\_domain) | Managed Login domain prefix. |
| <a name="output_hosted_ui_url"></a> [hosted\_ui\_url](#output\_hosted\_ui\_url) | Base URL of the Cognito Managed Login pages. |
| <a name="output_issuer_url"></a> [issuer\_url](#output\_issuer\_url) | OIDC issuer URL used by the API Gateway JWT authorizer. |
| <a name="output_user_pool_arn"></a> [user\_pool\_arn](#output\_user\_pool\_arn) | ARN of the Cognito user pool. |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID of the Cognito user pool. |
<!-- END_TF_DOCS -->
