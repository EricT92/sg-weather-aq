variable "aws_region" {
  description = "AWS region to deploy into. Singapore by default (data residency close to data.gov.sg users)."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix used for all resource names."
  type        = string
  default     = "outsystems-platform"
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
  default     = "platform-team"
}

variable "vpc_cidr" {
  description = "CIDR block for the platform VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "At least two AZs, so the load balancer and Multi-AZ databases are highly available."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway (cheaper) instead of one per AZ (more resilient)."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public load balancer (e.g. a corporate range for non-production)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate covering every environment hostname (e.g. *.example.com)."
  type        = string
}

variable "outsystems_version" {
  description = "OutSystems 11 Platform Server version installed by the bootstrap script."
  type        = string
  default     = "11.42.1"
}

variable "windows_ami_ssm_parameter" {
  description = "Public SSM parameter that resolves to the latest Windows Server AMI supported by OutSystems 11."
  type        = string
  default     = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

variable "environments" {
  description = <<-EOT
    One entry per OutSystems environment. A typical OutSystems 11 factory is
    Development -> Quality -> Production, plus a dedicated LifeTime environment
    that manages deployments between them.
  EOT
  type = map(object({
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
  }))

  default = {
    dev = {
      hostname                 = "dev.outsystems.example.com"
      controller_instance_type = "m5.large"
      frontend_instance_type   = "m5.large"
      frontend_min             = 1
      frontend_max             = 1
      db_instance_class        = "db.m5.large"
      db_allocated_storage     = 50
      db_multi_az              = false
      deletion_protection      = false
      backup_retention_days    = 3
    }
    qa = {
      hostname                 = "qa.outsystems.example.com"
      controller_instance_type = "m5.large"
      frontend_instance_type   = "m5.large"
      frontend_min             = 1
      frontend_max             = 2
      db_instance_class        = "db.m5.large"
      db_allocated_storage     = 50
      db_multi_az              = false
      deletion_protection      = false
      backup_retention_days    = 7
    }
    prod = {
      hostname                 = "app.outsystems.example.com"
      controller_instance_type = "m5.xlarge"
      frontend_instance_type   = "m5.xlarge"
      frontend_min             = 2
      frontend_max             = 4
      db_instance_class        = "db.m5.xlarge"
      db_allocated_storage     = 100
      db_multi_az              = true
      deletion_protection      = true
      backup_retention_days    = 30
    }
    lifetime = {
      hostname                 = "lifetime.outsystems.example.com"
      controller_instance_type = "m5.large"
      frontend_instance_type   = "m5.large"
      frontend_min             = 1
      frontend_max             = 1
      db_instance_class        = "db.m5.large"
      db_allocated_storage     = 50
      db_multi_az              = false
      deletion_protection      = true
      backup_retention_days    = 14
    }
  }

  validation {
    condition     = contains(keys(var.environments), "lifetime")
    error_message = "A 'lifetime' environment is required to manage deployments between OutSystems environments."
  }
}
