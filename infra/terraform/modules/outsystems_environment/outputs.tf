output "database_endpoint" {
  description = "Platform database endpoint."
  value       = aws_db_instance.platform.address
}

output "controller_private_ip" {
  description = "Private IP of the deployment controller."
  value       = aws_instance.controller.private_ip
}

output "frontend_asg_name" {
  description = "Auto Scaling group of front-end servers."
  value       = aws_autoscaling_group.frontend.name
}
