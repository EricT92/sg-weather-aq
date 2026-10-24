output "security_group_id" {
  description = "Load balancer security group ID."
  value       = aws_security_group.alb.id
}

output "https_listener_arn" {
  description = "HTTPS listener that environments attach host rules to."
  value       = aws_lb_listener.https.arn
}

output "dns_name" {
  description = "Load balancer DNS name."
  value       = aws_lb.this.dns_name
}
