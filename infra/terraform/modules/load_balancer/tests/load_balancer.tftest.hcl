mock_provider "aws" {}

variables {
  name                  = "test"
  vpc_id                = "vpc-0123456789abcdef0"
  vpc_cidr              = "10.20.0.0/16"
  public_subnet_ids     = ["subnet-aaaa", "subnet-bbbb"]
  allowed_ingress_cidrs = ["0.0.0.0/0"]
  certificate_arn       = "arn:aws:acm:ap-southeast-1:123456789012:certificate/test"
}

run "http_redirects_to_https" {
  command = plan

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "redirect"
    error_message = "Plain HTTP must redirect to HTTPS."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].redirect[0].protocol == "HTTPS"
    error_message = "The redirect must go to HTTPS."
  }
}

run "https_uses_modern_tls_policy" {
  command = plan

  assert {
    condition     = aws_lb_listener.https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "The HTTPS listener must use a TLS 1.2+/1.3 security policy."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "Invalid HTTP headers must be dropped (request smuggling protection)."
  }
}

run "egress_is_limited_to_the_vpc" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_egress_rule.to_vpc.cidr_ipv4 == "10.20.0.0/16"
    error_message = "The load balancer may only send traffic into the VPC."
  }
}

run "rejects_a_non_acm_certificate" {
  command = plan

  variables {
    certificate_arn = "not-a-certificate"
  }

  expect_failures = [var.certificate_arn]
}
