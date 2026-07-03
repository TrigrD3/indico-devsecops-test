# =============================================================================
# CodePipeline Module - Outputs
# =============================================================================
# Exports key resource identifiers and ARNs for use by consuming modules
# or root configurations.
# =============================================================================

# -----------------------------------------------------------------------------
# CodePipeline
# -----------------------------------------------------------------------------

output "pipeline_id" {
  description = "The ID of the CodePipeline."
  value       = aws_codepipeline.this.id
}

output "pipeline_arn" {
  description = "The ARN of the CodePipeline."
  value       = aws_codepipeline.this.arn
}

output "pipeline_name" {
  description = "The name of the CodePipeline."
  value       = aws_codepipeline.this.name
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

output "pipeline_role_arn" {
  description = "The ARN of the IAM role used by the CodePipeline."
  value       = aws_iam_role.codepipeline.arn
}

output "pipeline_role_name" {
  description = "The name of the IAM role used by the CodePipeline."
  value       = aws_iam_role.codepipeline.name
}

# -----------------------------------------------------------------------------
# S3 Artifact Bucket
# -----------------------------------------------------------------------------

output "artifact_bucket_name" {
  description = "The name of the S3 bucket used for pipeline artifacts."
  value       = local.artifact_bucket_name
}

output "artifact_bucket_arn" {
  description = "The ARN of the S3 bucket used for pipeline artifacts. Only set when the bucket is created by this module."
  value       = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].arn : null
}

# -----------------------------------------------------------------------------
# CodeStar Connection
# -----------------------------------------------------------------------------

output "codestar_connection_arn" {
  description = "The ARN of the CodeStar Connection used for source integration."
  value       = local.codestar_connection_arn
}

output "codestar_connection_status" {
  description = "The status of the CodeStar Connection (PENDING, AVAILABLE, ERROR). Only set when created by this module."
  value       = var.create_codestar_connection ? aws_codestarconnections_connection.this[0].connection_status : null
}
