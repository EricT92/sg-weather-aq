# Offline tests for one OutSystems environment. The AMI lookup is mocked so no
# AWS credentials are needed.
mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }
}

variables {
  name                      = "test-prod"
  environment               = "prod"
  vpc_id                    = "vpc-0123456789abcdef0"
  vpc_cidr                  = "10.20.0.0/16"
  app_subnet_ids            = ["subnet-app-a", "subnet-app-b"]
  db_subnet_ids             = ["subnet-db-a", "subnet-db-b"]
  alb_security_group_id     = "sg-0123456789abcdef0"
  https_listener_arn        = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:listener/app/test/abc/def"
  listener_rule_priority    = 120
  instance_profile_name     = "test-profile"
  installers_bucket_name    = "test-installers"
  outsystems_version        = "11.42.1"
  windows_ami_ssm_parameter = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"

  config = {
    hostname                 = "app.example.com"
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
}

run "production_database_is_resilient_and_private" {
  command = plan

  assert {
    condition     = aws_db_instance.platform.multi_az == true
    error_message = "Production database must be Multi-AZ."
  }

  assert {
    condition     = aws_db_instance.platform.deletion_protection == true
    error_message = "Production database must have deletion protection."
  }

  assert {
    condition     = aws_db_instance.platform.storage_encrypted == true
    error_message = "Database storage must be encrypted."
  }

  assert {
    condition     = aws_db_instance.platform.publicly_accessible == false
    error_message = "Database must never be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.platform.manage_master_user_password == true
    error_message = "Database password must be managed by RDS/Secrets Manager, not hard-coded."
  }
}

run "database_only_reachable_from_platform_servers" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_frontend.from_port == 1433 && aws_vpc_security_group_ingress_rule.db_from_frontend.cidr_ipv4 == null
    error_message = "SQL Server must only be reachable from the front-end security group, never from a CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_controller.cidr_ipv4 == null
    error_message = "SQL Server must only be reachable from the controller security group, never from a CIDR."
  }
}

run "frontends_scale_with_configuration" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.frontend.min_size == 2 && aws_autoscaling_group.frontend.max_size == 4
    error_message = "Front-end Auto Scaling group must follow the environment sizing."
  }

  assert {
    condition     = aws_lb_listener_rule.host.priority == 120
    error_message = "Each environment's listener rule must use its own priority."
  }
}

run "servers_require_imdsv2_and_encrypted_disks" {
  command = plan

  assert {
    condition     = aws_instance.controller.metadata_options[0].http_tokens == "required"
    error_message = "Instance metadata must require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.controller.root_block_device[0].encrypted == true
    error_message = "Server disks must be encrypted."
  }
}

run "development_database_is_cheaper" {
  command = plan

  variables {
    name        = "test-dev"
    environment = "dev"
    config = {
      hostname                 = "dev.example.com"
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
  }

  assert {
    condition     = aws_db_instance.platform.multi_az == false && aws_db_instance.platform.skip_final_snapshot == true
    error_message = "Development database should be single-AZ and skip the final snapshot."
  }
}

run "rejects_invalid_frontend_sizing" {
  command = plan

  variables {
    config = {
      hostname                 = "app.example.com"
      controller_instance_type = "m5.large"
      frontend_instance_type   = "m5.large"
      frontend_min             = 3
      frontend_max             = 2
      db_instance_class        = "db.m5.large"
      db_allocated_storage     = 50
      db_multi_az              = false
      deletion_protection      = false
      backup_retention_days    = 7
    }
  }

  expect_failures = [var.config]
}
