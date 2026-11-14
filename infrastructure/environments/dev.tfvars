# Development: cheapest footprint, disposable data. ~ idle cost is dominated by
# the NAT gateway, ALB and WAF; Aurora scales to zero and tasks run on Spot.
environment = "dev"

deletion_protection = false
log_retention_days  = 7

# Network
vpc_cidr                    = "10.20.0.0/16"
single_nat_gateway          = true
interface_endpoint_services = []

# Edge
cloudfront_price_class       = "PriceClass_100"
waf_rate_limit_per_5_minutes = 1000

# API / auth: JWT off so the API can be explored without signing in.
enable_auth                = false
enable_hosted_ui           = false
cognito_mfa                = "OFF"
api_throttling_rate_limit  = 50
api_throttling_burst_limit = 100

# App
app_cpu          = 256
app_memory       = 512
app_min_capacity = 1
app_max_capacity = 2
use_fargate_spot = true

# Aurora Serverless v2: pause after 5 idle minutes
aurora_min_capacity                 = 0
aurora_max_capacity                 = 2
aurora_instance_count               = 1
aurora_backup_retention_days        = 1
aurora_enhanced_monitoring_interval = 0
aurora_performance_insights         = false
