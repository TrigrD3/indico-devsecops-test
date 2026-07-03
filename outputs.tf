# =============================================================================
# Root Configuration - Outputs
# =============================================================================

# --- VPC / Network ---
output "vpc_id" {
  description = "ID of the VPC used for deployment."
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets used for the ALB."
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets used for ECS tasks."
  value       = local.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "The public Elastic IP of the NAT Gateway if a new VPC was created."
  value       = local.create_vpc ? module.vpc[0].nat_gateway_public_ip : null
}

# --- ALB ---
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the ALB."
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = module.alb.target_group_arn
}

# --- ECS ---
output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = module.ecs.service_name
}

# --- CodeBuild / CodePipeline ---
output "codebuild_project_name" {
  description = "Name of the CodeBuild project."
  value       = module.codebuild.project_name
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline."
  value       = module.codepipeline.pipeline_arn
}

output "pipeline_artifact_bucket" {
  description = "S3 bucket name used for pipeline artifacts."
  value       = module.codepipeline.artifact_bucket_name
}

output "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection for GitHub."
  value       = module.codepipeline.codestar_connection_arn
}

output "application_url" {
  description = "URL to access the deployed application."
  value       = var.enable_https ? "https://${module.alb.alb_dns_name}" : "http://${module.alb.alb_dns_name}"
}
