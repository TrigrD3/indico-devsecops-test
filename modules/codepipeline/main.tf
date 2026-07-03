# =============================================================================
# CodePipeline Module - Main Resources
# =============================================================================
# Creates a production-grade AWS CodePipeline with:
#   1. S3 artifact bucket (versioned, encrypted, lifecycle-managed)
#   2. IAM role with least-privilege permissions
#   3. CodeStar Connection for GitHub source integration
#   4. 3-stage pipeline: Source → Build → Deploy (ECS)
#
# The Deploy stage is optional and controlled via `enable_deploy_stage`.
# The S3 bucket and CodeStar Connection can be externally provided.
# =============================================================================

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Consistent resource naming prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # Resolve artifact bucket name: created or externally provided
  artifact_bucket_name = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].id : var.existing_s3_bucket

  # Resolve CodeStar Connection ARN: created or externally provided
  codestar_connection_arn = var.create_codestar_connection ? aws_codestarconnections_connection.this[0].arn : var.existing_codestar_connection_arn

  # Default tags merged with user-supplied tags
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "codepipeline"
  }

  tags = merge(local.default_tags, var.tags)
}

# =============================================================================
# 1. S3 ARTIFACT BUCKET
# =============================================================================
# Stores pipeline artifacts (source output, build output) with encryption,
# versioning, and lifecycle management. Public access is fully blocked.
# =============================================================================

resource "aws_s3_bucket" "artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket        = "${local.name_prefix}-codepipeline-artifacts"
  force_destroy = true # Allow Terraform to destroy bucket with contents

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-codepipeline-artifacts"
  })
}

# --- Versioning: protects against accidental overwrites ---
resource "aws_s3_bucket_versioning" "artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Server-Side Encryption: AES256 (SSE-S3) by default ---
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# --- Block All Public Access: defense-in-depth ---
resource "aws_s3_bucket_public_access_block" "artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle Rules: auto-expire old artifacts ---
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    id     = "expire-pipeline-artifacts"
    status = "Enabled"

    filter {}

    # Expire current versions after configured number of days
    expiration {
      days = var.artifact_expiration_days
    }

    # Clean up non-current versions after 7 days
    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    # Clean up incomplete multipart uploads after 3 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

# =============================================================================
# 2. IAM ROLE & POLICY FOR CODEPIPELINE
# =============================================================================
# Least-privilege IAM role that grants CodePipeline only the permissions it
# needs: S3 artifact access, CodeBuild triggering, ECS deployment, CodeStar
# connection usage, and IAM PassRole for downstream services.
# =============================================================================

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodePipelineAssume"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-codepipeline-role"
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # --- S3: Read/write pipeline artifacts ---
      {
        Sid    = "S3ArtifactAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.artifact_bucket_name}",
          "arn:aws:s3:::${local.artifact_bucket_name}/*"
        ]
      },

      # --- CodeBuild: Trigger and monitor builds ---
      {
        Sid    = "CodeBuildAccess"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.codebuild_project_name}"
      },

      # --- ECS: Deploy updated services (only if deploy stage is enabled) ---
      {
        Sid    = "ECSDeployAccess"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      },

      # --- CodeStar Connections: Use the GitHub connection ---
      {
        Sid    = "CodeStarConnectionAccess"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = local.codestar_connection_arn
      },

      # --- IAM: PassRole for ECS task execution and CodeBuild service roles ---
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" = [
              "ecs-tasks.amazonaws.com",
              "codebuild.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# =============================================================================
# 3. CODESTAR CONNECTION (GitHub)
# =============================================================================
# Creates a CodeStar Connection for GitHub source integration.
# NOTE: After creation, the connection will be in PENDING status.
# You must manually complete the handshake via the AWS Console.
# =============================================================================

resource "aws_codestarconnections_connection" "this" {
  count = var.create_codestar_connection ? 1 : 0

  name          = "${local.name_prefix}-github"
  provider_type = var.codestar_provider_type

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-github-connection"
  })
}

# =============================================================================
# 4. CODEPIPELINE
# =============================================================================
# 3-stage pipeline:
#   Stage 1 - Source:  Pulls code from GitHub via CodeStar Connection
#   Stage 2 - Build:   Runs CodeBuild project to build/test/package
#   Stage 3 - Deploy:  (Optional) Deploys to ECS via rolling update
#
# The Deploy stage uses a `dynamic` block so it is only created when
# `enable_deploy_stage = true`.
# =============================================================================

resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  # --- Artifact Store: S3 bucket for inter-stage artifacts ---
  artifact_store {
    location = local.artifact_bucket_name
    type     = "S3"
  }

  # -------------------------------------------------------------------------
  # Stage 1: Source (GitHub via CodeStar Connection)
  # -------------------------------------------------------------------------
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = local.codestar_connection_arn
        FullRepositoryId = var.source_repository
        BranchName       = var.source_branch
        DetectChanges    = var.detect_changes
        # Output the full clone for CodeBuild to access .git metadata
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  # -------------------------------------------------------------------------
  # Stage 2: Build (CodeBuild)
  # -------------------------------------------------------------------------
  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }

  # -------------------------------------------------------------------------
  # Stage 3: Deploy (ECS) — Only created when enable_deploy_stage = true
  # -------------------------------------------------------------------------
  dynamic "stage" {
    for_each = var.enable_deploy_stage ? [1] : []

    content {
      name = "Deploy"

      action {
        name            = "ECS_Deploy"
        category        = "Deploy"
        owner           = "AWS"
        provider        = "ECS"
        version         = "1"
        input_artifacts = ["build_output"]

        configuration = {
          ClusterName = var.ecs_cluster_name
          ServiceName = var.ecs_service_name
          FileName    = "imagedefinitions.json"
        }
      }
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-pipeline"
  })

  # Ensure IAM role and policy are fully created before the pipeline
  depends_on = [aws_iam_role_policy.codepipeline]
}
