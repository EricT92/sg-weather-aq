output "installers_bucket_name" {
  description = "Name of the private installers bucket."
  value       = aws_s3_bucket.installers.bucket
}

output "instance_profile_name" {
  description = "Instance profile attached to every OutSystems server."
  value       = aws_iam_instance_profile.outsystems_server.name
}
