output "vpc_id" {
  description = "ID of the platform VPC."
  value       = module.network.vpc_id
}

output "load_balancer_dns_name" {
  description = "Point every environment hostname (CNAME/alias) at this DNS name."
  value       = module.load_balancer.dns_name
}

output "environment_urls" {
  description = "Public URL of each OutSystems environment."
  value       = { for k, v in var.environments : k => "https://${v.hostname}" }
}

output "database_endpoints" {
  description = "Platform database endpoint per environment."
  value       = { for k, m in module.environment : k => m.database_endpoint }
}

output "installers_bucket" {
  description = "Upload the OutSystems license file and installers here."
  value       = module.shared.installers_bucket_name
}
