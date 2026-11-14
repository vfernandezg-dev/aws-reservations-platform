# Production: high availability in every tier, data protected on destroy.
environment = "prod"

deletion_protection = true
log_retention_days  = 365

# Network: NAT gateway per AZ and private endpoints for AWS APIs
vpc_cidr           = "10.40.0.0/16"
single_nat_gateway = false
interface_endpoint_services = [
  "ecr.api",
  "ecr.dkr",
  "logs",
  "secretsmanager",
]

# Edge
cloudfront_price_class       = "PriceClass_200"
waf_rate_limit_per_5_minutes = 2000

# API / auth
enable_auth                = true
enable_hosted_ui           = true
cognito_mfa                = "OPTIONAL"
api_throttling_rate_limit  = 500
api_throttling_burst_limit = 1000

# App: on-demand Fargate, at least one task per AZ
app_cpu          = 512
app_memory       = 1024
app_min_capacity = 2
app_max_capacity = 6
use_fargate_spot = false

# RDS PostgreSQL: Multi-AZ standby with automatic failover
db_instance_class               = "db.t4g.small"
db_allocated_storage            = 20
db_max_allocated_storage        = 200
db_multi_az                     = true
db_backup_retention_days        = 14
db_enhanced_monitoring_interval = 60
db_performance_insights         = true
