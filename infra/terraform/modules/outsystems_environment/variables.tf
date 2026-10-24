variable "name" {
  description = "Name prefix for this environment, e.g. outsystems-platform-prod."
  type        = string
}

variable "environment" {
  description = "Environment key: dev, qa, prod or lifetime."
  type        = string
}

variable "config" {
  description = "Sizing and resilience settings for this environment."
  type = object({
    hostname                 = string
    controller_instance_type = string
    frontend_instance_type   = string
    frontend_min             = number
    frontend_max             = number
    db_instance_class        = string
    db_allocated_storage     = number
    db_multi_az              = bool
    deletion_protection      = bool
    backup_retention_days    = number
  })

  validation {
    condition     = var.config.frontend_min >= 1 && var.config.frontend_min <= var.config.frontend_max
    error_message = "frontend_min must be at least 1 and not greater than frontend_max."
  }

  validation {
    condition     = var.config.backup_retention_days >= 1 && var.config.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35 (RDS limit)."
  }
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
}

variable "app_subnet_ids" {
  description = "Private subnets for the OutSystems servers."
  type        = list(string)
}

variable "db_subnet_ids" {
  description = "Private subnets for the platform database."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group of the shared load balancer."
  type        = string
}

variable "https_listener_arn" {
  description = "HTTPS listener to attach this environment's host rule to."
  type        = string
}

variable "listener_rule_priority" {
  description = "Unique priority for this environment's listener rule."
  type        = number
}

variable "instance_profile_name" {
  description = "IAM instance profile for the servers."
  type        = string
}

variable "installers_bucket_name" {
  description = "Bucket holding the OutSystems license file and installers."
  type        = string
}

variable "outsystems_version" {
  description = "OutSystems 11 Platform Server version to install."
  type        = string
}

variable "windows_ami_ssm_parameter" {
  description = "SSM parameter resolving to the Windows Server AMI."
  type        = string
}

variable "db_engine" {
  description = "RDS SQL Server edition. Standard Edition supports Multi-AZ."
  type        = string
  default     = "sqlserver-se"
}

variable "db_timezone" {
  description = "SQL Server time zone. OutSystems stores date-times in server time."
  type        = string
  default     = "Singapore Standard Time"
}

variable "health_check_path" {
  description = "Path the load balancer uses to check front-end health."
  type        = string
  default     = "/"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for platform logs."
  type        = number
  default     = 30
}
