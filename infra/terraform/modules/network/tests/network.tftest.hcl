# Runs offline: the mocked AWS provider needs no credentials.
mock_provider "aws" {}

variables {
  name               = "test"
  vpc_cidr           = "10.20.0.0/16"
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
}

run "creates_three_subnet_tiers_in_every_az" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private_app) == 2 && length(aws_subnet.private_db) == 2
    error_message = "Expected a public, app and data subnet in each availability zone."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Subnets must not auto-assign public IPs."
  }
}

run "single_nat_gateway_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected one shared NAT gateway when single_nat_gateway = true."
  }
}

run "one_nat_gateway_per_az_when_requested" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Expected one NAT gateway per AZ when single_nat_gateway = false."
  }
}

run "rejects_a_single_availability_zone" {
  command = plan

  variables {
    availability_zones = ["ap-southeast-1a"]
  }

  expect_failures = [var.availability_zones]
}
