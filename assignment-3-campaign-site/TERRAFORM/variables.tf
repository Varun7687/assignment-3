variable "aws_region" {
  description = "AWS region for all assignment resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Resource-name prefix. Existing resources are NOT automatically adopted."
  type        = string
  default     = "northwind-campaign"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,21}$", var.project_name))
    error_message = "Use 3-22 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "notification_email" {
  description = "Email address for SNS launch/terminate events. Confirm the subscription after apply."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "Enter a valid email address for the SNS subscription."
  }
}

variable "repository_url" {
  description = "Public GitHub HTTPS clone URL; credentials are not supported or embedded."
  type        = string
  default     = "https://github.com/Varun7687/assignment-3.git"

  validation {
    condition     = can(regex("^https://github[.]com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+[.]git$", var.repository_url))
    error_message = "Use a public GitHub HTTPS URL ending in .git."
  }
}

variable "repository_branch" {
  description = "Assignment branch cloned at instance boot."
  type        = string
  default     = "assignment-3"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", var.repository_branch))
    error_message = "Use a branch name containing only letters, digits, dot, underscore, slash or hyphen."
  }
}

variable "release_ref" {
  description = "Optional immutable commit SHA or tag. Empty means the branch HEAD at boot time."
  type        = string
  default     = ""

  validation {
    condition     = var.release_ref == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", var.release_ref))
    error_message = "Use a commit SHA or tag containing only letters, digits, dot, underscore, slash or hyphen."
  }
}

variable "deployment_revision" {
  description = "Change this value to roll instances after a branch-only content update."
  type        = string
  default     = "initial"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.deployment_revision))
    error_message = "Use letters, digits, dot, underscore or hyphen."
  }
}

variable "existing_key_pair_name" {
  description = "Optional EXISTING EC2 key-pair name in this region. No key or SSH ingress is created."
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "Optional two distinct AZ names in aws_region; empty selects the first two available AZs."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || (length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2)
    error_message = "Supply either an empty list or exactly two distinct Availability Zones."
  }
}

variable "vpc_cidr" {
  description = "New VPC IPv4 CIDR. Four /24 subnets are calculated from a /16 network."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "Supply a valid IPv4 /16 network, for example 10.20.0.0/16."
  }
}

variable "ami_id" {
  description = "Optional pinned Amazon Linux 2023 x86_64 AMI ID for this region. Empty resolves AWS's current AL2023 AMI."
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[a-f0-9]+$", var.ami_id))
    error_message = "Use an AMI ID or leave empty."
  }
}

variable "extra_tags" {
  description = "Additional resource tags. Required project tags take precedence."
  type        = map(string)
  default     = {}
}
