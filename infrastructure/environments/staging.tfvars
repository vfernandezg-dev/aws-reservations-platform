# Staging: production-like topology at reduced size.
environment = "staging"

deletion_protection = false
log_retention_days  = 14

# Network
vpc_cidr                    = "10.30.0.0/16"
single_nat_gateway          = true
interface_endpoint_services = []

# Edge
cloudfront_price_class       = "PriceClass_100"
waf_rate_limit_per_5_minutes = 2000

# API / auth
enable_auth                = true
enable_hosted_ui           = true
cognito_mfa                = "OPTIONAL"
api_throttling_rate_limit  = 100
api_throttling_burst_limit = 200

# App
app_cpu          = 256
app_memory       = 512
app_min_capacity = 1
app_max_capacity = 3
use_fargate_spot = true

# Aurora Serverless v2
aurora_min_capacity                 = 0
aurora_max_capacity                 = 4
aurora_instance_count               = 1
aurora_backup_retention_days        = 3
aurora_enhanced_monitoring_interval = 0
aurora_performance_insights         = false
