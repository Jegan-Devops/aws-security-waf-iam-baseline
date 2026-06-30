terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.app_name}-waf"
  description = "Baseline WAF protecting ${var.app_name} ALB"
  scope       = "REGIONAL" # use CLOUDFRONT scope instead if attaching to CloudFront

  default_action {
    allow {}
  }

  # ---------------------------------------------------------------------
  # Rule 1: AWS Managed Common Rule Set — blocks known bad patterns
  # (SQLi, XSS, request smuggling) without writing custom signatures.
  # ---------------------------------------------------------------------
  rule {
    name     = "AWS-CommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------
  # Rule 2: Known bad inputs — protects against log4j-style exploit patterns
  # ---------------------------------------------------------------------
  rule {
    name     = "AWS-KnownBadInputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------
  # Rule 3: Rate limiting — the actual DDoS mitigation layer.
  # Blocks any single IP making more than 2000 requests in a 5-minute window.
  # ---------------------------------------------------------------------
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-waf-overall"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.app_name}-waf"
  }
}

# Associates the WebACL with an existing ALB — pass the real ALB ARN in production
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.alb_arn != "" ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
