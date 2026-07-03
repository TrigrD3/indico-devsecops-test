# =============================================================================
# CodeBuild Module - Main Resources
# =============================================================================
# Creates:
#   1. CloudWatch Log Group   - Build log storage with configurable retention
#   2. IAM Service Role       - Least-privilege role for CodeBuild execution
#   3. IAM Role Policy        - Inline policy scoped to required resources
#   4. CodeBuild Project      - Configurable build project
# =============================================================================

# Fetch current AWS account and region for ARN construction
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Consistent resource naming convention: <project>-<environment>
  resource_prefix = "${var.project_name}-${var.environment}"

  # Determine if any environment variables reference Secrets Manager or Parameter Store
  # to auto-detect required IAM permissions when not explicitly set
  has_secrets_manager_vars = anytrue([
    for env in var.environment_variables : env.type == "SECRETS_MANAGER"
  ])
  has_parameter_store_vars = anytrue([
    for env in var.environment_variables : env.type == "PARAMETER_STORE"
  ])

  # Final permission flags: explicit toggle OR auto-detected from env vars
  grant_secrets_manager = var.enable_secrets_manager || local.has_secrets_manager_vars
  grant_parameter_store = var.enable_parameter_store || local.has_parameter_store_vars

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "codebuild"
  })
}

# =============================================================================
# 1. CloudWatch Log Group
# =============================================================================
# Dedicated log group for CodeBuild output. Separated from the project resource
# so we can control retention, encryption, and lifecycle independently.
# =============================================================================

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.resource_prefix}"
  retention_in_days = var.log_retention_in_days == 0 ? null : var.log_retention_in_days
  kms_key_id        = var.log_group_kms_key_id

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-build-logs"
  })
}

# =============================================================================
# 2. IAM Service Role
# =============================================================================
# Trust policy allows only the CodeBuild service to assume this role.
# Condition restricts assumption to the current AWS account for security.
# =============================================================================

resource "aws_iam_role" "codebuild" {
  name = "${local.resource_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeBuildAssume"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-codebuild-role"
  })
}

# =============================================================================
# 3. IAM Role Policy (Inline - Least Privilege)
# =============================================================================
# Single inline policy with conditional statement blocks based on module config.
# Each statement is scoped to the minimum required resources.
# =============================================================================

resource "aws_iam_role_policy" "codebuild" {
  name = "${local.resource_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # -----------------------------------------------------------------------
      # CloudWatch Logs - Always required
      # Scoped to the specific log group created by this module
      # -----------------------------------------------------------------------
      [
        {
          Sid    = "CloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Resource = [
            aws_cloudwatch_log_group.codebuild.arn,
            "${aws_cloudwatch_log_group.codebuild.arn}:*",
          ]
        }
      ],

      # -----------------------------------------------------------------------
      # S3 Artifacts - Always required (for pipeline artifacts and cache)
      # Scoped to the specific S3 bucket provided
      # -----------------------------------------------------------------------
      [
        {
          Sid    = "S3ArtifactAccess"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Resource = [
            var.s3_bucket_arn,
            "${var.s3_bucket_arn}/*",
          ]
        }
      ],

      # -----------------------------------------------------------------------
      # ECR - Conditional: only when ECR repository ARNs are provided
      # Grants pull/push access for Docker image builds
      # -----------------------------------------------------------------------
      [
        for stmt in [
          {
            Sid    = "ECRAuthToken"
            Effect = "Allow"
            Action = [
              "ecr:GetAuthorizationToken",
            ]
            Resource = "*"
          },
          {
            Sid    = "ECRPullPush"
            Effect = "Allow"
            Action = [
              "ecr:BatchCheckLayerAvailability",
              "ecr:BatchGetImage",
              "ecr:GetDownloadUrlForLayer",
              "ecr:PutImage",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
            ]
            Resource = var.ecr_repository_arns
          }
        ] : stmt if length(var.ecr_repository_arns) > 0
      ],

      # -----------------------------------------------------------------------
      # Secrets Manager - Conditional: only when enabled or env vars require it
      # Scoped to secrets in the current account and region
      # -----------------------------------------------------------------------
      [
        for stmt in [
          {
            Sid    = "SecretsManagerRead"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue",
            ]
            Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:*"
          }
        ] : stmt if local.grant_secrets_manager
      ],

      # -----------------------------------------------------------------------
      # SSM Parameter Store - Conditional: only when enabled or env vars require it
      # Scoped to parameters in the current account and region
      # -----------------------------------------------------------------------
      [
        for stmt in [
          {
            Sid    = "ParameterStoreRead"
            Effect = "Allow"
            Action = [
              "ssm:GetParameters",
              "ssm:GetParameter",
            ]
            Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
          }
        ] : stmt if local.grant_parameter_store
      ],

      # -----------------------------------------------------------------------
      # VPC Access - Conditional: only when VPC config is provided
      # Required for CodeBuild to create/manage ENIs in the specified VPC
      # -----------------------------------------------------------------------
      [
        for stmt in [
          {
            Sid    = "VPCNetworkInterface"
            Effect = "Allow"
            Action = [
              "ec2:CreateNetworkInterface",
              "ec2:DeleteNetworkInterface",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeDhcpOptions",
              "ec2:DescribeVpcs",
            ]
            Resource = "*"
          },
          {
            Sid    = "VPCNetworkInterfacePermissions"
            Effect = "Allow"
            Action = [
              "ec2:CreateNetworkInterfacePermission",
            ]
            Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*"
            Condition = {
              StringEquals = {
                "ec2:AuthorizedService" = "codebuild.amazonaws.com"
                "ec2:Subnet" = var.vpc_config != null ? [
                  for subnet in var.vpc_config.subnets :
                  "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${subnet}"
                ] : []
              }
            }
          }
        ] : stmt if var.vpc_config != null
      ]
    )
  })
}

# =============================================================================
# 4. CodeBuild Project
# =============================================================================
# The build project itself with fully configurable environment, source,
# artifacts, caching, logging, and optional VPC configuration.
# =============================================================================

resource "aws_codebuild_project" "this" {
  name                   = local.resource_prefix
  description            = var.description
  service_role           = aws_iam_role.codebuild.arn
  build_timeout          = var.build_timeout
  concurrent_build_limit = var.concurrent_build_limit
  queued_timeout         = var.queued_timeout

  # ---------------------------------------------------------------------------
  # Build Environment
  # ---------------------------------------------------------------------------
  environment {
    compute_type                = var.compute_type
    image                       = var.image
    type                        = var.environment_type
    privileged_mode             = var.privileged_mode
    image_pull_credentials_type = var.image_pull_credentials_type

    # Inject all configured environment variables
    dynamic "environment_variable" {
      for_each = var.environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Source Configuration
  # ---------------------------------------------------------------------------
  source {
    type      = var.source_type
    location  = var.source_location
    buildspec = var.buildspec
  }

  # ---------------------------------------------------------------------------
  # Artifacts Configuration
  # ---------------------------------------------------------------------------
  artifacts {
    type = var.artifact_type
  }

  # ---------------------------------------------------------------------------
  # Cache Configuration
  # Uses local Docker layer caching to speed up Docker image builds.
  # LOCAL caching is free and requires no additional infrastructure.
  # ---------------------------------------------------------------------------
  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  # ---------------------------------------------------------------------------
  # CloudWatch Logs
  # Sends build output to the dedicated log group created above.
  # ---------------------------------------------------------------------------
  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build"
    }
  }

  # ---------------------------------------------------------------------------
  # VPC Configuration (Optional)
  # Enables builds to access resources within a private VPC (e.g., RDS,
  # ElastiCache, or internal services). Only created when vpc_config is set.
  # ---------------------------------------------------------------------------
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      vpc_id             = vpc_config.value.vpc_id
      subnets            = vpc_config.value.subnets
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(local.common_tags, {
    Name = local.resource_prefix
  })
}
