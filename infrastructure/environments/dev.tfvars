# Development: cheapest footprint, disposable data. ~ idle cost is dominated by
# the NAT gateway, ALB and WAF; the database is a db.t4g.micro and tasks run on Spot.
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

# RDS PostgreSQL: smallest Graviton class, single-AZ, 1 day of backups
db_instance_class               = "db.t4g.micro"
db_allocated_storage            = 20
db_max_allocated_storage        = 50
db_multi_az                     = false
db_backup_retention_days        = 1
db_enhanced_monitoring_interval = 0
db_performance_insights         = false
