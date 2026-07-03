# =============================================================================
# VPC Module - Input Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project. Used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block notation."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets. Must have at least 2 for high availability ALB."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnet CIDR blocks are required for ALB high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for the private subnets. Must have at least 2 to match availability zones."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least 1 private subnet CIDR block is required."
  }
}

variable "availability_zones" {
  description = "List of availability zones in the region. If empty, will dynamically query available AZs."
  type        = list(string)
  default     = []
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}
