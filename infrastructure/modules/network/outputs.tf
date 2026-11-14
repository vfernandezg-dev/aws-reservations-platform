output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (NAT gateways only), ordered like var.azs."
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "app_subnet_ids" {
  description = "IDs of the private application subnets, ordered like var.azs."
  value       = [for az in var.azs : aws_subnet.app[az].id]
}

output "data_subnet_ids" {
  description = "IDs of the isolated data subnets, ordered like var.azs."
  value       = [for az in var.azs : aws_subnet.data[az].id]
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways (egress IPs of the workload)."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}

output "s3_prefix_list_id" {
  description = "Managed prefix list ID of the S3 gateway endpoint."
  value       = aws_vpc_endpoint.s3.prefix_list_id
}
