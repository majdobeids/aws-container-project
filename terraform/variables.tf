variable "aws_region" {
  description = "AWS region for the project"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name used for project resources and tags"
  type        = string
  default     = "container-final"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project))
    error_message = "Use 3-25 lowercase letters, numbers or hyphens, starting with a letter."
  }
}

variable "admin_cidr" {
  description = "Your public IPv4 address followed by /32 for SSH access"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && can(regex("/32$", var.admin_cidr))
    error_message = "Use one public IPv4 address followed by /32."
  }
}

variable "http_cidr" {
  description = "IPv4 range allowed to access the web application"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.http_cidr))
    error_message = "Use a valid IPv4 CIDR."
  }
}

variable "instance_type" {
  description = "EC2 instance type for both servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Choose t2.micro or t3.micro."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key, relative to the Terraform directory"
  type        = string
  default     = "../.local/id_ed25519.pub"
}
