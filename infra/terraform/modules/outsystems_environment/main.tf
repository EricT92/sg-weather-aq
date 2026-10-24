data "aws_ssm_parameter" "windows_ami" {
  name = var.windows_ami_ssm_parameter
}

locals {
  is_lifetime = var.environment == "lifetime"

  # OutSystems 11 internal service ports between controller and front-ends:
  # 12000 Deployment Controller, 12001 Deployment Service, 12002 Scheduler,
  # 5672 cache invalidation (RabbitMQ). Verify against the OutSystems network
  # requirements for the installed platform version.
  platform_ports = [
    { from = 12000, to = 12002, description = "OutSystems platform services" },
    { from = 5672, to = 5672, description = "Cache invalidation service (RabbitMQ)" },
  ]
}

# ---------------------------------------------------------------------------
# Security groups: one set per environment, so dev servers can never reach
# the production database.
# ---------------------------------------------------------------------------
resource "aws_security_group" "frontend" {
  name_prefix = "${var.name}-frontend-"
  description = "OutSystems front-end servers (${var.environment})"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "controller" {
  name_prefix = "${var.name}-controller-"
  description = "OutSystems deployment controller (${var.environment})"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "Platform database (${var.environment})"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "HTTP from the load balancer (TLS terminates at the ALB)"
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_controller" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "Deployment Service calls from the controller"
  referenced_security_group_id = aws_security_group.controller.id
  ip_protocol                  = "tcp"
  from_port                    = 12001
  to_port                      = 12001
}

resource "aws_vpc_security_group_ingress_rule" "controller_from_frontend" {
  for_each = { for p in local.platform_ports : "${p.from}-${p.to}" => p }

  security_group_id            = aws_security_group.controller.id
  description                  = each.value.description
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.from
  to_port                      = each.value.to
}

resource "aws_vpc_security_group_ingress_rule" "db_from_frontend" {
  security_group_id            = aws_security_group.db.id
  description                  = "SQL Server from front-ends"
  referenced_security_group_id = aws_security_group.frontend.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}

resource "aws_vpc_security_group_ingress_rule" "db_from_controller" {
  security_group_id            = aws_security_group.db.id
  description                  = "SQL Server from the deployment controller"
  referenced_security_group_id = aws_security_group.controller.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}

# Servers may talk to anything inside the VPC, and only HTTPS to the internet
# (via NAT): installers, Windows updates, external APIs like data.gov.sg.
resource "aws_vpc_security_group_egress_rule" "servers_to_vpc" {
  for_each = {
    frontend   = aws_security_group.frontend.id
    controller = aws_security_group.controller.id
  }

  security_group_id = each.value
  description       = "All traffic inside the VPC"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "servers_https_out" {
  for_each = {
    frontend   = aws_security_group.frontend.id
    controller = aws_security_group.controller.id
  }

  security_group_id = each.value
  description       = "Outbound HTTPS via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# ---------------------------------------------------------------------------
# Platform database: SQL Server on RDS. Password is generated and rotated by
# RDS in Secrets Manager, so it never appears in code or Terraform state.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name}-"
  subnet_ids  = var.db_subnet_ids
}

resource "aws_db_instance" "platform" {
  identifier_prefix = "${var.name}-"
  engine            = var.db_engine
  license_model     = "license-included"
  instance_class    = var.config.db_instance_class
  timezone          = var.db_timezone

  allocated_storage     = var.config.db_allocated_storage
  max_allocated_storage = var.config.db_allocated_storage * 4
  storage_type          = "gp3"
  storage_encrypted     = true

  username                    = "osadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.config.db_multi_az

  backup_retention_period    = var.config.backup_retention_days
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = var.config.deletion_protection
  skip_final_snapshot        = !var.config.deletion_protection
  final_snapshot_identifier  = var.config.deletion_protection ? "${var.name}-final" : null

  enabled_cloudwatch_logs_exports = ["agent", "error"]
  performance_insights_enabled    = true
}

resource "aws_cloudwatch_log_group" "platform" {
  name              = "/outsystems/${var.environment}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# Servers: one deployment controller + an auto-scaling group of front-ends.
# Both run Windows Server and are bootstrapped by the same script.
# ---------------------------------------------------------------------------
locals {
  bootstrap_common = {
    environment        = var.environment
    is_lifetime        = local.is_lifetime
    outsystems_version = var.outsystems_version
    installers_bucket  = var.installers_bucket_name
    db_host            = aws_db_instance.platform.address
    db_secret_arn      = aws_db_instance.platform.master_user_secret[0].secret_arn
    log_group          = aws_cloudwatch_log_group.platform.name
  }
}

resource "aws_instance" "controller" {
  ami                    = data.aws_ssm_parameter.windows_ami.value
  instance_type          = var.config.controller_instance_type
  subnet_id              = var.app_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.controller.id]
  iam_instance_profile   = var.instance_profile_name
  ebs_optimized          = true
  monitoring             = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/bootstrap.ps1.tftpl", merge(local.bootstrap_common, {
    role          = "controller"
    controller_ip = ""
  }))

  tags = { Name = "${var.name}-controller", Role = "deployment-controller" }
}

resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.name}-frontend-"
  image_id      = data.aws_ssm_parameter.windows_ami.value
  instance_type = var.config.frontend_instance_type
  ebs_optimized = true

  vpc_security_group_ids = [aws_security_group.frontend.id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = "gp3"
      volume_size = 100
      encrypted   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/bootstrap.ps1.tftpl", merge(local.bootstrap_common, {
    role          = "frontend"
    controller_ip = aws_instance.controller.private_ip
  })))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-frontend", Role = "front-end" }
  }
}

resource "aws_lb_target_group" "frontend" {
  name_prefix = "os-fe-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.name}-frontend-"
  min_size            = var.config.frontend_min
  max_size            = var.config.frontend_max
  desired_capacity    = var.config.frontend_min
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.frontend.arn]

  # Windows + Platform Server installation takes a while on first boot.
  health_check_type         = "ELB"
  health_check_grace_period = 1800

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }
}

resource "aws_lb_listener_rule" "host" {
  listener_arn = var.https_listener_arn
  priority     = var.listener_rule_priority

  condition {
    host_header {
      values = [var.config.hostname]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
