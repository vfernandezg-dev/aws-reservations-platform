###############################################################################
# Request path:
#   Users -> CloudFront (+WAF) -> S3 (static) | /api/* -> HTTP API (JWT)
#         -> VPC Link -> internal ALB -> ECS Fargate -> Aurora Serverless v2
###############################################################################

# Shared secret between CloudFront and the internal ALB. Requests that do not
# come through CloudFront (and therefore WAF) never reach the application.
resource "random_password" "origin_verify" {
  length  = 64
  special = false
}

###############################################################################
# Foundation
###############################################################################

# Customer managed keys: one in the primary region (logs, Aurora, secrets, SNS)
# and one in us-east-1 for edge resources (WAF logs, global alarm topic).
module "kms" {
  source = "./modules/kms"

  name                    = local.name
  deletion_window_in_days = var.deletion_protection ? 30 : 7
}

module "kms_global" {
  source = "./modules/kms"

  name                    = "${local.name}-global"
  region                  = "us-east-1"
  deletion_window_in_days = var.deletion_protection ? 30 : 7
}

module "logging" {
  source = "./modules/logging"

  name           = local.name
  retention_days = var.log_retention_days
  force_destroy  = !var.deletion_protection
}

module "network" {
  source = "./modules/network"

  name                        = local.name
  cidr_block                  = var.vpc_cidr
  azs                         = local.azs
  single_nat_gateway          = var.single_nat_gateway
  interface_endpoint_services = var.interface_endpoint_services
  flow_logs_bucket_arn        = module.logging.bucket_arn
}

module "security" {
  source = "./modules/security"

  name     = local.name
  vpc_id   = module.network.vpc_id
  app_port = local.app_port
}

###############################################################################
# Data tier
###############################################################################

module "aurora" {
  source = "./modules/aurora"

  name                         = local.name
  subnet_ids                   = module.network.data_subnet_ids
  security_group_id            = module.security.db_security_group_id
  min_capacity                 = var.aurora_min_capacity
  max_capacity                 = var.aurora_max_capacity
  instance_count               = var.aurora_instance_count
  backup_retention_days        = var.aurora_backup_retention_days
  performance_insights_enabled = var.aurora_performance_insights
  enhanced_monitoring_interval = var.aurora_enhanced_monitoring_interval
  kms_key_arn                  = module.kms.key_arn
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = !var.deletion_protection
  log_retention_days           = var.log_retention_days
}

###############################################################################
# Application tier
###############################################################################

module "alb" {
  source = "./modules/alb"

  name                      = local.name
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.app_subnet_ids
  security_group_id         = module.security.alb_security_group_id
  target_port               = local.app_port
  origin_verify_header_name = local.origin_header
  origin_verify_secret      = random_password.origin_verify.result
  access_logs_bucket        = module.logging.bucket_id
  access_logs_prefix        = module.logging.alb_prefix
  deletion_protection       = var.deletion_protection
}

module "ecs" {
  source = "./modules/ecs"

  name                    = local.name
  image                   = local.app_image
  image_tag               = var.app_image_tag
  container_port          = local.app_port
  cpu                     = var.app_cpu
  memory                  = var.app_memory
  min_capacity            = var.app_min_capacity
  max_capacity            = var.app_max_capacity
  use_fargate_spot        = var.use_fargate_spot
  subnet_ids              = module.network.app_subnet_ids
  security_group_id       = module.security.app_security_group_id
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  db_host                 = module.aurora.endpoint
  db_port                 = module.aurora.port
  db_name                 = module.aurora.database_name
  db_secret_arn           = module.aurora.master_user_secret_arn
  kms_key_arn             = module.kms.key_arn
  log_retention_days      = var.log_retention_days
}

###############################################################################
# Identity + API
###############################################################################

module "auth" {
  source = "./modules/auth"

  name                = local.name
  deletion_protection = var.deletion_protection
  mfa_configuration   = var.cognito_mfa
  callback_urls       = var.enable_hosted_ui ? ["${module.cdn.url}/"] : []
  logout_urls         = var.enable_hosted_ui ? ["${module.cdn.url}/"] : []
}

module "api" {
  source = "./modules/api"

  name                       = local.name
  vpc_link_subnet_ids        = module.network.app_subnet_ids
  vpc_link_security_group_id = module.security.vpc_link_security_group_id
  alb_listener_arn           = module.alb.listener_arn
  enable_auth                = var.enable_auth
  jwt_issuer                 = module.auth.issuer_url
  jwt_audience               = [module.auth.client_id]
  throttling_rate_limit      = var.api_throttling_rate_limit
  throttling_burst_limit     = var.api_throttling_burst_limit
  log_retention_days         = var.log_retention_days
  kms_key_arn                = module.kms.key_arn
}

###############################################################################
# Edge
###############################################################################

module "storage" {
  source = "./modules/storage"

  name          = local.name
  environment   = var.environment
  force_destroy = !var.deletion_protection
}

module "waf" {
  source = "./modules/waf"

  name                     = local.name
  rate_limit_per_5_minutes = var.waf_rate_limit_per_5_minutes
  blocked_country_codes    = var.waf_blocked_country_codes
  log_retention_days       = var.log_retention_days
  kms_key_arn              = module.kms_global.key_arn
}

module "cdn" {
  source = "./modules/cdn"

  name                               = local.name
  static_bucket_id                   = module.storage.bucket_id
  static_bucket_arn                  = module.storage.bucket_arn
  static_bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  api_endpoint                       = module.api.api_endpoint
  origin_verify_header_name          = local.origin_header
  origin_verify_secret               = random_password.origin_verify.result
  web_acl_arn                        = module.waf.web_acl_arn
  price_class                        = var.cloudfront_price_class
  log_bucket_arn                     = module.logging.bucket_arn
}

###############################################################################
# Observability
###############################################################################

module "monitoring" {
  source = "./modules/monitoring"

  name                       = local.name
  alarm_email                = var.alarm_email
  alb_arn_suffix             = module.alb.arn_suffix
  target_group_arn_suffix    = module.alb.target_group_arn_suffix
  ecs_cluster_name           = module.ecs.cluster_name
  ecs_service_name           = module.ecs.service_name
  api_id                     = module.api.api_id
  aurora_cluster_identifier  = module.aurora.cluster_identifier
  cloudfront_distribution_id = module.cdn.distribution_id
  waf_web_acl_name           = module.waf.web_acl_name
  kms_key_arn                = module.kms.key_arn
  global_kms_key_arn         = module.kms_global.key_arn
}
