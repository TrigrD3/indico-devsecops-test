# =============================================================================
# Root Configuration - Provider & Terraform Settings
# =============================================================================
# Pins Terraform and provider versions for reproducible builds.
# Configures the AWS provider with default tagging so every resource is
# automatically tagged with Project, Environment, and ManagedBy.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: configure remote backend for team collaboration.
  # Uncomment and customise before running `terraform init`.
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "devsecops/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
