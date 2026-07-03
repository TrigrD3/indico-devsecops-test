# =============================================================================
# CodeBuild Module - Outputs
# =============================================================================
# Exposes resource identifiers and ARNs for use by consuming modules
# (e.g., CodePipeline, monitoring, or cross-stack references).
# =============================================================================

# -----------------------------------------------------------------------------
# CodeBuild Project
# -----------------------------------------------------------------------------

output "project_id" {
  description = "The ID of the CodeBuild project."
  value       = aws_codebuild_project.this.id
}

output "project_arn" {
  description = "The ARN of the CodeBuild project."
  value       = aws_codebuild_project.this.arn
}

output "project_name" {
  description = "The name of the CodeBuild project."
  value       = aws_codebuild_project.this.name
}

# -----------------------------------------------------------------------------
# IAM Service Role
# -----------------------------------------------------------------------------

output "service_role_arn" {
  description = "The ARN of the IAM service role used by the CodeBuild project."
  value       = aws_iam_role.codebuild.arn
}

output "service_role_name" {
  description = "The name of the IAM service role used by the CodeBuild project."
  value       = aws_iam_role.codebuild.name
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

output "log_group_name" {
  description = "The name of the CloudWatch Log Group for build logs."
  value       = aws_cloudwatch_log_group.codebuild.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for build logs."
  value       = aws_cloudwatch_log_group.codebuild.arn
}
