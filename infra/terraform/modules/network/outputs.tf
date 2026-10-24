output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancer, NAT)."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private subnet IDs for OutSystems servers."
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "Private subnet IDs for databases (no internet route)."
  value       = aws_subnet.private_db[*].id
}
