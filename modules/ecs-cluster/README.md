# ECS Cluster Module

This module provisions a shared AWS ECS Cluster with Container Insights and CloudWatch logging configured.

## Resources Created
*   **ECS Cluster** (`aws_ecs_cluster`): Shared compute cluster.
*   **Capacity Providers** (`aws_ecs_cluster_capacity_providers`): Configured with FARGATE and FARGATE_SPOT providers.
*   **CloudWatch Log Group** (`aws_cloudwatch_log_group`): Central logging storage for services.

## Usage
```hcl
module "ecs_cluster" {
  source       = "../ecs-cluster"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}
```
