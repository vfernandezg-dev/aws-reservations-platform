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

# RDS PostgreSQL: same engine and size as dev with longer backups
db_instance_class               = "db.t4g.micro"
db_allocated_storage            = 20
db_max_allocated_storage        = 100
db_multi_az                     = false
db_backup_retention_days        = 3
db_enhanced_monitoring_interval = 0
db_performance_insights         = false
