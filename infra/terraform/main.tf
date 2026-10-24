locals {
  name = var.project_name

  # Deterministic, non-overlapping ALB listener rule priorities per environment.
  environment_keys = sort(keys(var.environments))
}

module "network" {
  source = "./modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
}

module "shared" {
  source = "./modules/shared"

  name = local.name
}

module "load_balancer" {
  source = "./modules/load_balancer"

  name                  = local.name
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_ids     = module.network.public_subnet_ids
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  certificate_arn       = var.acm_certificate_arn
}

module "environment" {
  source   = "./modules/outsystems_environment"
  for_each = var.environments

  name        = "${local.name}-${each.key}"
  environment = each.key
  config      = each.value

  vpc_id                 = module.network.vpc_id
  vpc_cidr               = module.network.vpc_cidr
  app_subnet_ids         = module.network.private_app_subnet_ids
  db_subnet_ids          = module.network.private_db_subnet_ids
  alb_security_group_id  = module.load_balancer.security_group_id
  https_listener_arn     = module.load_balancer.https_listener_arn
  listener_rule_priority = 100 + index(local.environment_keys, each.key) * 10

  instance_profile_name     = module.shared.instance_profile_name
  installers_bucket_name    = module.shared.installers_bucket_name
  outsystems_version        = var.outsystems_version
  windows_ami_ssm_parameter = var.windows_ami_ssm_parameter
}
