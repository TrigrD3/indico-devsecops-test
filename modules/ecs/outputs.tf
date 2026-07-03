################################################################################
# ECS Cluster
################################################################################

output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

################################################################################
# ECS Service
################################################################################

output "service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

################################################################################
# Task Definition
################################################################################

output "task_definition_arn" {
  description = "Full ARN of the task definition (includes revision)."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family name of the task definition."
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Latest revision number of the task definition."
  value       = aws_ecs_task_definition.this.revision
}

################################################################################
# Security Group
################################################################################

output "security_group_id" {
  description = "ID of the security group attached to ECS tasks."
  value       = aws_security_group.ecs_tasks.id
}

################################################################################
# IAM Roles
################################################################################

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (used by the ECS agent)."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (used by the application container)."
  value       = aws_iam_role.task.arn
}

################################################################################
# CloudWatch
################################################################################

output "log_group_name" {
  description = "Name of the CloudWatch log group for container logs."
  value       = aws_cloudwatch_log_group.this.name
}
