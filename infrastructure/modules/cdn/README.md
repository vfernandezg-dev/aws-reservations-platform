# CDN (CloudFront)

Single public entry point: the static site from S3, and `/api/*` routed to the API Gateway HTTP API.

## Design

- AWS managed cache, origin request and response headers policies, looked up by name (no hard-coded IDs): `CachingOptimized` for S3, `CachingDisabled` + `AllViewerExceptHostHeader` for the API (forwarding the viewer Host header makes API Gateway answer 403), and `SecurityHeadersPolicy` everywhere.
- HTTP/2 + HTTP/3, IPv6, HTTPS-only viewers, AWS WAF Web ACL attached.
- Injects a secret `X-Origin-Verify` header towards the API origin. The internal ALB rejects requests without it, so the execute-api URL cannot be used to bypass CloudFront and WAF.
- Owns the static bucket policy (OAC + deny non-TLS).
- CloudFront standard logging v2 (`aws_cloudwatch_log_delivery*`) to the central log bucket.
- Optional custom domain (`aliases` + an ACM certificate in us-east-1, validated together).

## Usage

```hcl
module "cdn" {
  source = "./modules/cdn"

  name                               = "reservations-dev"
  static_bucket_id                   = module.storage.bucket_id
  static_bucket_arn                  = module.storage.bucket_arn
  static_bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  api_endpoint                       = module.api.api_endpoint
  origin_verify_secret               = random_password.origin_verify.result
  web_acl_arn                        = module.waf.web_acl_arn
  log_bucket_arn                     = module.logging.bucket_arn
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.70 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.70 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudwatch_log_delivery.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_s3_bucket_policy.static](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_cloudfront_cache_policy.caching_disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.caching_optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.all_viewer_except_host](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |
| [aws_cloudfront_response_headers_policy.security_headers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_response_headers_policy) | data source |
| [aws_iam_policy_document.static_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_endpoint"></a> [api\_endpoint](#input\_api\_endpoint) | Invoke URL of the API Gateway HTTP API (https://<id>.execute-api.<region>.amazonaws.com). | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_origin_verify_secret"></a> [origin\_verify\_secret](#input\_origin\_verify\_secret) | Value of the secret origin header (validated by the internal ALB). | `string` | n/a | yes |
| <a name="input_static_bucket_arn"></a> [static\_bucket\_arn](#input\_static\_bucket\_arn) | ARN of the S3 bucket with static content. | `string` | n/a | yes |
| <a name="input_static_bucket_id"></a> [static\_bucket\_id](#input\_static\_bucket\_id) | Name of the S3 bucket with static content. | `string` | n/a | yes |
| <a name="input_static_bucket_regional_domain_name"></a> [static\_bucket\_regional\_domain\_name](#input\_static\_bucket\_regional\_domain\_name) | Regional domain name of the static content bucket. | `string` | n/a | yes |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | ARN of the WAFv2 Web ACL (CLOUDFRONT scope) to attach. | `string` | n/a | yes |
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | Optional ACM certificate ARN in us-east-1 for the custom domain names. | `string` | `null` | no |
| <a name="input_aliases"></a> [aliases](#input\_aliases) | Optional custom domain names (CNAMEs). Requires acm\_certificate\_arn. | `list(string)` | `[]` | no |
| <a name="input_enable_access_logs"></a> [enable\_access\_logs](#input\_enable\_access\_logs) | Deliver CloudFront standard logs (v2) to log\_bucket\_arn. A separate flag keeps `count` known at plan time. | `bool` | `true` | no |
| <a name="input_log_bucket_arn"></a> [log\_bucket\_arn](#input\_log\_bucket\_arn) | ARN of the S3 bucket for CloudFront standard logs (required when enable\_access\_logs is true). | `string` | `null` | no |
| <a name="input_origin_verify_header_name"></a> [origin\_verify\_header\_name](#input\_origin\_verify\_header\_name) | Name of the secret header CloudFront adds to API requests. | `string` | `"X-Origin-Verify"` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | CloudFront price class: PriceClass\_100, PriceClass\_200 or PriceClass\_All. | `string` | `"PriceClass_100"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | ARN of the CloudFront distribution. |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | ID of the CloudFront distribution. |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | CloudFront domain name (dxxxx.cloudfront.net). |
| <a name="output_url"></a> [url](#output\_url) | Public HTTPS URL of the platform. |
<!-- END_TF_DOCS -->
