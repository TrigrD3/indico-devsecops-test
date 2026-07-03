#--------------------------------------------------------------
# Project & Environment
#--------------------------------------------------------------

variable "project_name" {
  description = "Name of the project. Used as a prefix for all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

#--------------------------------------------------------------
# Networking
#--------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g., vpc-0abc1234def56789a)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service network configuration."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to reach the container port. Defaults to VPC-internal only."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = alltrue([for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All entries in allowed_cidr_blocks must be valid CIDR notation."
  }
}

#--------------------------------------------------------------
# Container Configuration
#--------------------------------------------------------------

variable "container_image" {
  description = "Docker image URI for the container (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest)."
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 80

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "container_environment" {
  description = "Map of environment variables to inject into the container."
  type        = map(string)
  default     = {}
}

variable "health_check_path" {
  description = "HTTP path for the container health check (e.g., /healthz)."
  type        = string
  default     = "/health"
}

#--------------------------------------------------------------
# Task Definition Sizing
#--------------------------------------------------------------

variable "cpu" {
  description = "CPU units for the Fargate task (256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Memory (MiB) for the Fargate task. Must be compatible with the chosen CPU value."
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192, 16384, 30720], var.memory)
    error_message = "memory must be a valid Fargate memory value (512, 1024, 2048, ..., 30720)."
  }
}

#--------------------------------------------------------------
# Service Configuration
#--------------------------------------------------------------

variable "desired_count" {
  description = "Desired number of running tasks for the ECS service."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must be zero or a positive integer."
  }
}

variable "min_healthy_percent" {
  description = "Lower limit (%) of running tasks during a deployment."
  type        = number
  default     = 100

  validation {
    condition     = var.min_healthy_percent >= 0 && var.min_healthy_percent <= 200
    error_message = "min_healthy_percent must be between 0 and 200."
  }
}

variable "max_percent" {
  description = "Upper limit (%) of running tasks during a deployment."
  type        = number
  default     = 200

  validation {
    condition     = var.max_percent >= 100 && var.max_percent <= 400
    error_message = "max_percent must be between 100 and 400."
  }
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for interactive debugging via `aws ecs execute-command`."
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Load Balancer (optional)
#--------------------------------------------------------------

variable "target_group_arn" {
  description = "ARN of an ALB/NLB target group. Leave empty to skip load balancer attachment."
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Capacity Provider Strategy
#--------------------------------------------------------------

variable "capacity_providers" {
  description = "List of capacity providers to associate with the cluster."
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]

  validation {
    condition     = length(var.capacity_providers) > 0
    error_message = "At least one capacity provider must be specified."
  }
}

variable "default_capacity_provider_strategy" {
  description = <<-EOT
    Default capacity provider strategy for the cluster.
    Each element is an object with:
      - capacity_provider: Name of the capacity provider (e.g., FARGATE).
      - weight:            Relative weight for task placement.
      - base:              Minimum number of tasks on this provider.
  EOT
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  default = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 2
      base              = 0
    }
  ]
}

#--------------------------------------------------------------
# Logging
#--------------------------------------------------------------

variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch log events."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a valid CloudWatch retention value."
  }
}

#--------------------------------------------------------------
# IAM
#--------------------------------------------------------------

variable "task_role_policy_arns" {
  description = "List of IAM policy ARNs to attach to the ECS task role (application-level permissions)."
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# Tags
#--------------------------------------------------------------

variable "tags" {
  description = "Map of additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
