# =============================================================================
# CodeBuild Module - Input Variables
# =============================================================================
# All configurable parameters for the AWS CodeBuild project, IAM role,
# and CloudWatch log group resources.
# =============================================================================

# -----------------------------------------------------------------------------
# Project Identification
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the CodeBuild project. Used as a prefix for all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{1,254}$", var.project_name))
    error_message = "Project name must start with a letter, contain only alphanumeric characters, hyphens, or underscores, and be between 2 and 255 characters."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, production). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "description" {
  description = "Human-readable description for the CodeBuild project."
  type        = string
  default     = "Managed by Terraform"
}

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------

variable "build_timeout" {
  description = "Build timeout in minutes. AWS allows 5-480 minutes."
  type        = number
  default     = 30

  validation {
    condition     = var.build_timeout >= 5 && var.build_timeout <= 480
    error_message = "Build timeout must be between 5 and 480 minutes."
  }
}

variable "concurrent_build_limit" {
  description = "Maximum number of concurrent builds allowed. Set to null for unlimited."
  type        = number
  default     = 1

  validation {
    condition     = var.concurrent_build_limit == null || var.concurrent_build_limit >= 1
    error_message = "Concurrent build limit must be at least 1 or null for unlimited."
  }
}

variable "queued_timeout" {
  description = "Time in minutes a build is allowed to remain queued before timing out. Valid range: 5-480."
  type        = number
  default     = 60

  validation {
    condition     = var.queued_timeout >= 5 && var.queued_timeout <= 480
    error_message = "Queued timeout must be between 5 and 480 minutes."
  }
}

# -----------------------------------------------------------------------------
# Build Environment
# -----------------------------------------------------------------------------

variable "compute_type" {
  description = "CodeBuild compute type for the build environment."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"

  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE",
      "BUILD_GENERAL1_XLARGE",
      "BUILD_GENERAL1_2XLARGE",
      "BUILD_LAMBDA_1GB",
      "BUILD_LAMBDA_2GB",
      "BUILD_LAMBDA_4GB",
      "BUILD_LAMBDA_8GB",
      "BUILD_LAMBDA_10GB",
    ], var.compute_type)
    error_message = "Compute type must be a valid AWS CodeBuild compute type (e.g., BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_LAMBDA_*)."
  }
}

variable "image" {
  description = "Docker image identifier for the build environment (e.g., AWS managed image or ECR URI)."
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "environment_type" {
  description = "Type of build environment. Must match the chosen image architecture."
  type        = string
  default     = "LINUX_CONTAINER"

  validation {
    condition = contains([
      "LINUX_CONTAINER",
      "LINUX_GPU_CONTAINER",
      "ARM_CONTAINER",
      "WINDOWS_CONTAINER",
      "WINDOWS_SERVER_2019_CONTAINER",
      "LINUX_LAMBDA_CONTAINER",
      "ARM_LAMBDA_CONTAINER",
    ], var.environment_type)
    error_message = "Environment type must be a valid CodeBuild environment type."
  }
}

variable "privileged_mode" {
  description = "Enable privileged mode for the build container. Required for Docker-in-Docker (building Docker images)."
  type        = bool
  default     = true
}

variable "image_pull_credentials_type" {
  description = "Type of credentials for pulling the build image. CODEBUILD for AWS-managed images, SERVICE_ROLE for private ECR/registry."
  type        = string
  default     = "CODEBUILD"

  validation {
    condition     = contains(["CODEBUILD", "SERVICE_ROLE"], var.image_pull_credentials_type)
    error_message = "Image pull credentials type must be CODEBUILD or SERVICE_ROLE."
  }
}

# -----------------------------------------------------------------------------
# Source Configuration
# -----------------------------------------------------------------------------

variable "source_type" {
  description = "Type of source provider for the build input."
  type        = string
  default     = "CODEPIPELINE"

  validation {
    condition = contains([
      "CODEPIPELINE",
      "CODECOMMIT",
      "GITHUB",
      "GITHUB_ENTERPRISE",
      "BITBUCKET",
      "S3",
      "NO_SOURCE",
    ], var.source_type)
    error_message = "Source type must be one of: CODEPIPELINE, CODECOMMIT, GITHUB, GITHUB_ENTERPRISE, BITBUCKET, S3, NO_SOURCE."
  }
}

variable "source_location" {
  description = "Location of the source code (e.g., repository URL or S3 path). Not required when source_type is CODEPIPELINE or NO_SOURCE."
  type        = string
  default     = null
}

variable "buildspec" {
  description = "Path to the buildspec file relative to source root, or inline buildspec YAML. Defaults to 'buildspec.yml' at the source root."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Artifacts Configuration
# -----------------------------------------------------------------------------

variable "artifact_type" {
  description = "Type of build output artifact."
  type        = string
  default     = "CODEPIPELINE"

  validation {
    condition     = contains(["CODEPIPELINE", "S3", "NO_ARTIFACTS"], var.artifact_type)
    error_message = "Artifact type must be one of: CODEPIPELINE, S3, NO_ARTIFACTS."
  }
}

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------

variable "environment_variables" {
  description = <<-EOT
    List of environment variables to set in the build environment.
    Each object requires:
      - name:  Variable name
      - value: Variable value (or SSM/Secrets Manager key for non-PLAINTEXT types)
      - type:  One of PLAINTEXT, PARAMETER_STORE, SECRETS_MANAGER
  EOT
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  default = []

  validation {
    condition = alltrue([
      for env in var.environment_variables :
      contains(["PLAINTEXT", "PARAMETER_STORE", "SECRETS_MANAGER"], env.type)
    ])
    error_message = "Each environment variable type must be one of: PLAINTEXT, PARAMETER_STORE, SECRETS_MANAGER."
  }
}

# -----------------------------------------------------------------------------
# VPC Configuration (Optional)
# -----------------------------------------------------------------------------

variable "vpc_config" {
  description = <<-EOT
    Optional VPC configuration for builds that need access to private resources.
    When provided, all three fields are required:
      - vpc_id:             VPC ID
      - subnets:            List of subnet IDs (private subnets recommended)
      - security_group_ids: List of security group IDs
  EOT
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------

variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch logs. Set to 0 for indefinite retention."
  type        = number
  default     = 90

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value (0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653)."
  }
}

variable "log_group_kms_key_id" {
  description = "ARN of the KMS key to encrypt CloudWatch log group. Set to null to use default encryption."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# IAM / Resource ARN References
# -----------------------------------------------------------------------------

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for build artifacts and/or cache. Required for artifact storage permissions."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.s3_bucket_arn))
    error_message = "S3 bucket ARN must be a valid ARN starting with 'arn:aws:s3:::'."
  }
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that the build project needs pull/push access to."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.ecr_repository_arns :
      can(regex("^arn:aws:ecr:", arn))
    ])
    error_message = "Each ECR repository ARN must be a valid ARN starting with 'arn:aws:ecr:'."
  }
}

variable "enable_secrets_manager" {
  description = "Grant the CodeBuild service role permission to read from AWS Secrets Manager. Enable if using SECRETS_MANAGER type environment variables."
  type        = bool
  default     = false
}

variable "enable_parameter_store" {
  description = "Grant the CodeBuild service role permission to read from SSM Parameter Store. Enable if using PARAMETER_STORE type environment variables."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
