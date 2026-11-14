output "cluster_identifier" {
  description = "Identifier of the Aurora cluster (CloudWatch metric dimension)."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.this.arn
}

output "endpoint" {
  description = "Writer endpoint."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Load-balanced reader endpoint."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "Database port."
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_rds_cluster.this.database_name
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret with the master credentials."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}
