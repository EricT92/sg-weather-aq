# Plans the whole platform (all environments) against a mocked AWS provider.
mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "ap-southeast-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  acm_certificate_arn = "arn:aws:acm:ap-southeast-1:123456789012:certificate/test"
}

run "plans_every_outsystems_environment" {
  command = plan

  assert {
    condition     = length(output.environment_urls) == 4
    error_message = "Expected dev, qa, prod and lifetime environments."
  }

  assert {
    condition     = output.environment_urls["prod"] == "https://app.outsystems.example.com"
    error_message = "Production URL should be derived from its hostname over HTTPS."
  }
}

run "lifetime_environment_is_mandatory" {
  command = plan

  variables {
    environments = {
      dev = {
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
  }

  expect_failures = [var.environments]
}
