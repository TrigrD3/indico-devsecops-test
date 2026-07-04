# AWS ECS Cluster Terraform Module

This module provisions a shared, production-ready **Amazon ECS Cluster** with Container Insights enabled, CloudWatch logging integration, and cost-optimized Fargate capacity provider strategies.

---

## 🏛️ Architecture & Resources Created

*   **ECS Cluster** (`aws_ecs_cluster`): Shared compute cluster boundary for container tasks.
*   **Cluster Capacity Providers** (`aws_ecs_cluster_capacity_providers`): Associated with FARGATE and FARGATE_SPOT launch types to facilitate automatic cost-optimization.
*   **CloudWatch Log Group** (`aws_cloudwatch_log_group`): Central logging storage for container stdout/stderr streams.

---

## 🚀 Usage

```hcl
module "ecs_cluster" {
  source       = "../ecs-cluster"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags

  log_retention_in_days = 30
}
```

---

## ⚙️ Inputs

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `project_name` | `string` | *Required* | Name of the project. Used to prefix resource names. |
| `environment` | `string` | *Required* | Deployment environment (dev, staging, production). |
| `tags` | `map(string)` | `{}` | Key-value pairs appended to default tags. |
| `capacity_providers` | `list(string)` | `["FARGATE", "FARGATE_SPOT"]` | List of Fargate capacity providers to associate with the cluster. |
| `default_capacity_provider_strategy` | `list(object)` | *(Fargate base, Spot weight)* | Configuration mapping FARGATE base allocation and FARGATE_SPOT scaling weights. |
| `log_retention_in_days` | `number` | `30` | Number of days to retain CloudWatch logs (validated standard values). |

---

## 📤 Outputs

| Name | Description |
| :--- | :--- |
| `cluster_id` | The ID / ARN of the ECS cluster. |
| `cluster_name` | The name of the ECS cluster. |
| `log_group_name` | The name of the CloudWatch Log Group. |
| `log_group_arn` | The ARN of the CloudWatch Log Group. |

---

## 🔒 Security & Best Practices

1.  **Container Insights Enabled:** Cluster metrics and task behaviors are automatically sent to CloudWatch for active diagnostics and performance monitoring.
2.  **Encrypted Log Retention:** Container logs are centralized and configured with automatic lifecycle retention to control AWS data storage costs.
3.  **Fargate Spot Cost Optimization:** Default capacity strategies route baseline tasks to standard Fargate and subsequent tasks to discounted Fargate Spot instances automatically.
