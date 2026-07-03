# =============================================================================
# CodePipeline Module - Input Variables
# =============================================================================
# All configurable inputs for the AWS CodePipeline module.
# Variables are grouped by concern: naming, source, build, deploy, storage,
# connection, and tagging.
# =============================================================================

# -----------------------------------------------------------------------------
# General / Naming
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project. Used as a prefix for all resource names to ensure uniqueness and traceability."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,48}[a-zA-Z0-9]$", var.project_name))
    error_message = "project_name must be 3-50 characters, start with a letter, end with alphanumeric, and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, production). Controls naming and tagging."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

# -----------------------------------------------------------------------------
# Source Stage Configuration
# -----------------------------------------------------------------------------

variable "source_repository" {
  description = "Full GitHub repository identifier in the format 'owner/repo' (e.g., 'my-org/my-app')."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$", var.source_repository))
    error_message = "source_repository must be in the format 'owner/repo' (e.g., 'my-org/my-app')."
  }
}

variable "source_branch" {
  description = "The branch to track for source changes. Pipeline triggers on pushes to this branch."
  type        = string
  default     = "main"
}

variable "detect_changes" {
  description = "Whether the pipeline should automatically detect changes in the source repository and trigger a new execution."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Build Stage Configuration
# -----------------------------------------------------------------------------

variable "codebuild_project_name" {
  description = "Name of the existing AWS CodeBuild project to use in the Build stage. Must be pre-created."
  type        = string
}

# -----------------------------------------------------------------------------
# Deploy Stage Configuration (ECS)
# -----------------------------------------------------------------------------

variable "enable_deploy_stage" {
  description = "Whether to include the Deploy (ECS) stage in the pipeline. Set to false for build-only pipelines."
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to deploy to. Required when enable_deploy_stage is true."
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "Name of the ECS service to update during deployment. Required when enable_deploy_stage is true."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# S3 Artifact Bucket
# -----------------------------------------------------------------------------

variable "create_s3_bucket" {
  description = "Whether to create a new S3 bucket for pipeline artifacts. Set to false and provide existing_s3_bucket to reuse an existing bucket."
  type        = bool
  default     = true
}

variable "existing_s3_bucket" {
  description = "Name of an existing S3 bucket to use for pipeline artifacts. Only used when create_s3_bucket is false."
  type        = string
  default     = ""
}

variable "artifact_expiration_days" {
  description = "Number of days after which pipeline artifacts are automatically deleted via lifecycle policy."
  type        = number
  default     = 30

  validation {
    condition     = var.artifact_expiration_days >= 1 && var.artifact_expiration_days <= 365
    error_message = "artifact_expiration_days must be between 1 and 365."
  }
}

# -----------------------------------------------------------------------------
# CodeStar Connection (GitHub)
# -----------------------------------------------------------------------------

variable "create_codestar_connection" {
  description = "Whether to create a new CodeStar Connection for GitHub. Set to false and provide existing_codestar_connection_arn to reuse."
  type        = bool
  default     = true
}

variable "existing_codestar_connection_arn" {
  description = "ARN of an existing CodeStar Connection. Only used when create_codestar_connection is false."
  type        = string
  default     = ""
}

variable "codestar_provider_type" {
  description = "The source provider type for the CodeStar Connection. Typically 'GitHub' for GitHub.com repositories."
  type        = string
  default     = "GitHub"

  validation {
    condition     = contains(["GitHub", "Bitbucket", "GitHubEnterpriseServer", "GitLab", "GitLabSelfManaged"], var.codestar_provider_type)
    error_message = "codestar_provider_type must be one of: GitHub, Bitbucket, GitHubEnterpriseServer, GitLab, GitLabSelfManaged."
  }
}

# -----------------------------------------------------------------------------
# Tagging
# -----------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources created by this module. Merged with default tags (Project, Environment, ManagedBy)."
  type        = map(string)
  default     = {}
}
