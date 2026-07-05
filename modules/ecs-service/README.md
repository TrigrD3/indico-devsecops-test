# ECS Service Terraform Module

Production-ready Terraform module for deploying containerized applications on **AWS ECS Fargate** using a shared ECS Cluster.

---

## 🏛️ Architecture & Resources Created

This module provisions application-level resources for a Fargate service:
*   **ECS Service** (`aws_ecs_service`): Manages task lifecycle, rolling updates, and deployments.
*   **ECS Task Definition** (`aws_ecs_task_definition`): Specifies the container configurations (image, ports, env, logs, health checks).
*   **Security Group** (`aws_security_group`): Hardened firewall allowing ingress only on the container port.
*   **IAM Execution Role** (`aws_iam_role`): Grants the ECS agent permissions to pull images from ECR and write logs to CloudWatch.
*   **IAM Task Role** (`aws_iam_role`): Grants the containerized application permissions to call AWS APIs.

---

## 🚀 Usage

### Minimal Example
```hcl
module "ecs_service" {
  source = "../ecs-service"

  project_name    = "my-project"
  environment     = "dev"
  app_name        = "frontend"
  cluster_id      = module.ecs_cluster.cluster_id
  cluster_name    = module.ecs_cluster.cluster_name
  log_group_name  = module.ecs_cluster.log_group_name
  vpc_id          = "vpc-0abc1234def56789a"
  subnet_ids      = ["subnet-aaa", "subnet-bbb"]
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest"
}
```

### Production Example with ALB & IAM
```hcl
module "ecs_service" {
  source = "../ecs-service"

  project_name    = "payment-service"
  environment     = "production"
  app_name        = "api"
  cluster_id      = module.ecs_cluster.cluster_id
  cluster_name    = module.ecs_cluster.cluster_name
  log_group_name  = module.ecs_cluster.log_group_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/payment-service:v2.1.0"

  # Sizing
  cpu    = 1024
  memory = 2048

  # Scaling
  desired_count       = 4
  min_healthy_percent = 50
  max_percent         = 200

  # Networking
  container_port      = 8080
  allowed_cidr_blocks = ["10.0.0.0/16"]
  target_group_arn    = module.alb.target_group_arn
  health_check_path   = "/healthz"

  # Debugging
  enable_execute_command = true

  # Application-level IAM policies
  task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  tags = {
    Team       = "platform"
    CostCenter = "eng-1234"
  }
}
```

---

## ⚙️ Inputs

| Name | Description | Type | Default | Required |
|:---|:---|:---|:---|:---:|
| `project_name` | Project name prefix for all resources | `string` | — | ✅ |
| `environment` | Deployment environment (`dev`, `staging`, `production`) | `string` | — | ✅ |
| `app_name` | Name of this application service | `string` | `"app"` | ❌ |
| `cluster_id` | ID of the shared ECS cluster | `string` | — | ✅ |
| `cluster_name` | Name of the shared ECS cluster | `string` | — | ✅ |
| `log_group_name` | Name of the shared CloudWatch log group | `string` | — | ✅ |
| `vpc_id` | VPC ID for ECS resources | `string` | — | ✅ |
| `subnet_ids` | Subnet IDs for service networking | `list(string)` | — | ✅ |
| `container_image` | Docker image URI | `string` | — | ✅ |
| `container_port` | Port exposed by the container | `number` | `80` | ❌ |
| `container_environment` | Environment variables map | `map(string)` | `{}` | ❌ |
| `health_check_path` | HTTP path for health checks | `string` | `"/health"` | ❌ |
| `cpu` | Fargate task CPU units | `number` | `256` | ❌ |
| `memory` | Fargate task memory (MiB) | `number` | `512` | ❌ |
| `desired_count` | Number of running tasks | `number` | `2` | ❌ |
| `min_healthy_percent` | Min healthy % during deployment | `number` | `100` | ❌ |
| `max_percent` | Max % during deployment | `number` | `200` | ❌ |
| `enable_execute_command` | Enable ECS Exec | `bool` | `false` | ❌ |
| `target_group_arn` | ALB/NLB target group ARN | `string` | `""` | ❌ |
| `task_role_policy_arns` | Additional IAM policies for task role | `list(string)` | `[]` | ❌ |
| `allowed_cidr_blocks` | CIDR blocks allowed on container port | `list(string)` | `["10.0.0.0/8"]` | ❌ |
| `tags` | Additional tags for all resources | `map(string)` | `{}` | ❌ |

---

## 📤 Outputs

| Name | Description |
|:---|:---|
| `cluster_id` | Shared ECS cluster ID |
| `cluster_arn` | Shared ECS cluster ARN |
| `cluster_name` | Shared ECS cluster name |
| `service_id` | ECS service ID |
| `service_name` | ECS service name |
| `task_definition_arn` | Task definition ARN (includes revision) |
| `task_definition_family` | Task definition family name |
| `task_definition_revision` | Latest task definition revision |
| `security_group_id` | Security group ID for ECS tasks |
| `task_execution_role_arn` | Task execution role ARN |
| `task_role_arn` | Task role ARN |
| `log_group_name` | Shared CloudWatch log group name |

---

## 🔒 Security Best Practices Implemented

1.  **Least-Privilege Role Separation:** Splits task execution permissions (pulling images, writing logs) from task application permissions to prevent privilege escalation.
2.  **Network Isolation:** Tasks are deployed inside private VPC subnets. The task Security Group only allows ingress traffic from specified CIDR blocks on the container port.
3.  **Circuit Breaker Rollbacks:** Prevents broken releases from taking down active service containers by rolling back automatically on failure.
