# =============================================================================
# ALB Module - Input Variables
# =============================================================================
# Defines all configurable inputs for the Application Load Balancer module.
# Variables are grouped by: Naming/Tagging, Network, ALB Config, Target Group,
# Health Check, HTTPS/TLS, and Security.
# =============================================================================

# -----------------------------------------------------------------------------
# Naming & Tagging
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project. Used as a prefix for all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.project_name))
    error_message = "project_name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, production). Restricts to known environments to prevent accidental misconfigurations."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources. Merged with default tags (Project, Environment, ManagedBy)."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where the ALB and its security group will be created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g., vpc-0abc1234def56789a)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB. Must span at least 2 Availability Zones for high availability."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for ALB high availability across Availability Zones."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB on ports 80/443. Defaults to open (0.0.0.0/0). Restrict in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified."
  }
}

# -----------------------------------------------------------------------------
# ALB Configuration
# -----------------------------------------------------------------------------

variable "internal" {
  description = "If true, creates an internal ALB (private subnets). If false, creates an internet-facing ALB (public subnets)."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Time in seconds the ALB waits before closing idle connections. Increase for long-lived WebSocket/streaming connections."
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "enable_deletion_protection" {
  description = "If true, prevents accidental ALB deletion via the API/CLI. Enable in production; disable in dev/staging for teardown convenience."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Target Group Configuration
# -----------------------------------------------------------------------------

variable "container_port" {
  description = "Port on which the target containers (Fargate tasks) listen for traffic."
  type        = number
  default     = 80

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be a valid port number (1-65535)."
  }
}

variable "deregistration_delay" {
  description = "Time in seconds the ALB waits before deregistering a draining target. Lower values speed up deployments; higher values let in-flight requests complete."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "deregistration_delay must be between 0 and 3600 seconds."
  }
}

# -----------------------------------------------------------------------------
# Health Check Configuration
# -----------------------------------------------------------------------------

variable "health_check_path" {
  description = "HTTP path for ALB health checks against target group members. Should return 200 when the application is healthy."
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Seconds between consecutive health checks."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "health_check_interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Seconds to wait for a health check response before considering it failed."
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "health_check_timeout must be between 2 and 120 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks required to mark a target healthy."
  type        = number
  default     = 3

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "healthy_threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks required to mark a target unhealthy."
  type        = number
  default     = 3

  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "unhealthy_threshold must be between 2 and 10."
  }
}

variable "health_check_matcher" {
  description = "HTTP status codes that indicate a healthy target. Supports single codes (200), ranges (200-299), or comma-separated values (200,202)."
  type        = string
  default     = "200"
}

# -----------------------------------------------------------------------------
# HTTPS / TLS Configuration
# -----------------------------------------------------------------------------

variable "enable_https" {
  description = "If true, creates an HTTPS listener on port 443 and redirects HTTP to HTTPS. Requires certificate_arn."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener. Required when enable_https is true."
  type        = string
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "certificate_arn must be a valid ACM certificate ARN (arn:aws:acm:...) or an empty string."
  }
}

variable "ssl_policy" {
  description = "AWS SSL/TLS negotiation policy for the HTTPS listener. Defaults to TLS 1.3 with 1.2 fallback — the strongest generally-compatible policy."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
