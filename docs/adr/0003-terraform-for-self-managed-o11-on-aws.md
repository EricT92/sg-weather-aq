# ADR 0003: Terraform for a self-managed OutSystems 11 factory on AWS

**Status:** Accepted

## Context
The brief asks for Infrastructure as Code that deploys and operates the
OutSystems platform on AWS. Only OutSystems 11 can be self-managed (ODC is
fully managed by OutSystems), so the IaC targets an O11 factory.

## Decision
Use Terraform (AWS provider ~> 5.0) with reusable modules:

- `network`: VPC across 2 AZs, three subnet tiers (public / app / data). The data tier has no internet route.
- `shared`: encrypted private S3 bucket for installers and the license, and an EC2 role (SSM access, no RDP).
- `load_balancer`: one internet-facing ALB, HTTPS only (HTTP redirects), TLS 1.2/1.3 policy; host-based routing per environment.
- `outsystems_environment`: instantiated per environment (dev, qa, prod, lifetime) via `for_each`. Each gets a SQL Server RDS database, a deployment controller, an Auto Scaling group of front-ends and its own security groups.

Servers are bootstrapped with the community `Outsystems.SetupTools` PowerShell
module (prerequisites → Platform Server → configuration → Service Center → license).

## Consequences
- Environments differ only in data (`var.environments`), so dev and prod use
  identical, reviewed code; prod gets Multi-AZ, deletion protection, more front-ends.
- Database passwords are generated and stored by RDS in Secrets Manager
  (`manage_master_user_password`), never in code or state.
- Per-environment security groups isolate environments from each other.
- Tests run offline with `terraform test` and a mocked AWS provider, so CI
  needs no AWS account or credentials.
- Trade-off: it has not been applied to a real AWS account for this assessment
  (cost and an OutSystems self-managed license are required). It is validated
  through `terraform validate`, `terraform test`, TFLint and Checkov.
