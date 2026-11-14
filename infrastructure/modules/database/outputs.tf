output "identifier" {
  description = "Identifier of the DB instance (CloudWatch metric dimension)."
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "ARN of the DB instance."
  value       = aws_db_instance.this.arn
}

output "address" {
  description = "Hostname of the DB instance (private DNS, follows Multi-AZ failover)."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret with the master credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
