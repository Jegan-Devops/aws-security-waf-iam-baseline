variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "app_name" {
  type    = string
  default = "demo-app"
}

variable "alb_arn" {
  description = "ARN of an existing ALB to attach this WAF to. Leave blank to deploy the WebACL standalone for review."
  type        = string
  default     = ""
}
