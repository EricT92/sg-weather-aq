data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  rds_secret_arn_pattern = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds!*"
}

# ---------------------------------------------------------------------------
# Private bucket for OutSystems installers, the platform license file and
# exported solution packs (.osp). Encrypted, versioned, never public.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "installers" {
  bucket_prefix = "${var.name}-installers-"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "installers" {
  bucket = aws_s3_bucket.installers.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "installers" {
  bucket = aws_s3_bucket.installers.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "installers" {
  bucket = aws_s3_bucket.installers.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "installers" {
  bucket = aws_s3_bucket.installers.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# EC2 instance role. Servers are managed through SSM Session Manager, so no
# RDP port is ever opened to the internet.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "outsystems_server" {
  name_prefix        = "${var.name}-server-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.outsystems_server.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.outsystems_server.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Least privilege: read installers/license, and read only the RDS-managed
# database secrets (RDS names them "rds!...").
data "aws_iam_policy_document" "server_access" {
  statement {
    sid       = "ReadInstallers"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.installers.arn}/*"]
  }

  statement {
    sid       = "ListInstallers"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.installers.arn]
  }

  statement {
    sid       = "ReadRdsManagedSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.rds_secret_arn_pattern]
  }
}

resource "aws_iam_role_policy" "server_access" {
  name   = "outsystems-server-access"
  role   = aws_iam_role.outsystems_server.id
  policy = data.aws_iam_policy_document.server_access.json
}

resource "aws_iam_instance_profile" "outsystems_server" {
  name_prefix = "${var.name}-server-"
  role        = aws_iam_role.outsystems_server.name
}
