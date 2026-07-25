variable "allow_spoke_icmp" {
  description = "Whether test instances accept ICMP from the two spoke VPC CIDR blocks"
  type        = bool
  default     = true
}

variable "aws_profile" {
  description = "AWS CLI profile used by the AWS provider"
  type        = string
  default     = "aws-security-lab"
}

variable "aws_region" {
  description = "AWS region for the lab: us-east-1 primary or us-west-2 fallback"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "aws_region must be us-east-1 or us-west-2."
  }
}

variable "blocked_domains" {
  description = "Domain suffixes blocked by the stateful Network Firewall rule group"
  type        = list(string)
  default     = [".example.com"]

  validation {
    condition     = length(var.blocked_domains) > 0
    error_message = "blocked_domains must contain at least one domain."
  }
}

variable "environment" {
  description = "Environment name used in resource names and tags"
  type        = string
  default     = "lab"
}

variable "inspection_vpc_cidr" {
  description = "IPv4 CIDR block for the centralized inspection VPC"
  type        = string
  default     = "10.255.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type used for the two spoke test instances"
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "aws-firewall-tgw"
}

variable "retention_days" {
  description = "CloudWatch retention period for Network Firewall logs"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.retention_days)
    error_message = "retention_days must be one of 1, 3, 5, 7, 14, or 30."
  }
}

variable "spoke_vpc_cidrs" {
  description = "IPv4 CIDR blocks for the two spoke VPCs"
  type        = map(string)

  default = {
    spoke_a = "10.10.0.0/16"
    spoke_b = "10.20.0.0/16"
  }

  validation {
    condition = (
      length(var.spoke_vpc_cidrs) == 2 &&
      alltrue([for key in ["spoke_a", "spoke_b"] : contains(keys(var.spoke_vpc_cidrs), key)])
    )
    error_message = "spoke_vpc_cidrs must contain exactly spoke_a and spoke_b."
  }
}
