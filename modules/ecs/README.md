# ECS Terraform Module

Production-ready Terraform module for deploying containerized applications on **AWS ECS Fargate**.

## Architecture

```
                          ┌──────────────────────────────────┐
                          │         ECS Cluster              │
                          │   (Container Insights enabled)   │
                          │                                  │
                          │  ┌────────────────────────────┐  │
                          │  │       ECS Service           │  │
                          │  │  • Circuit breaker          │  │
                          │  │  • Rolling deployment       │  │
  ALB/NLB ──(optional)──▶ │  │  • ECS Exec support        │  │
                          │  │                            │  │
                          │  │  ┌──────────────────────┐  │  │
                          │  │  │   Fargate Task(s)    │  │  │
                          │  │  │  ┌────────────────┐  │  │  │
                          │  │  │  │   Container    │  │  │  │
                          │  │  │  │  • Health chk  │──┼──┼──┼──▶ CloudWatch Logs
                          │  │  │  │  • Env vars    │  │  │  │
                          │  │  │  └────────────────┘  │  │  │
                          │  │  └──────────────────────┘  │  │
                          │  └────────────────────────────┘  │
                          └──────────────────────────────────┘
                                        │
                          ┌─────────────┼─────────────┐
                          │             │             │
                    Security Group  Task Exec Role  Task Role
                    (ingress/egress)  (ECR, Logs)   (App perms)
```

## Features

| Feature | Description |
|---|---|
| **Fargate** | Serverless compute — no EC2 instances to manage |
| **Fargate Spot** | Cost-optimized capacity provider strategy (configurable) |
| **Container Insights** | Cluster-level metrics and log collection |
| **Circuit Breaker** | Automatic rollback on failed deployments |
| **ECS Exec** | Optional interactive container debugging |
| **Load Balancer** | Optional ALB/NLB target group integration |
| **IAM Least Privilege** | Separate execution role (infra) and task role (app) |
| **Health Checks** | Configurable HTTP health check path |

## Usage

### Minimal Example

```hcl
module "ecs" {
  source = "./modules/ecs"

  project_name    = "my-api"
  environment     = "dev"
  vpc_id          = "vpc-0abc1234def56789a"
  subnet_ids      = ["subnet-aaa", "subnet-bbb"]
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest"
}
```

### Production Example with ALB

```hcl
module "ecs" {
  source = "./modules/ecs"

  project_name    = "payment-service"
  environment     = "production"
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

  # Application config
  container_environment = {
    DATABASE_URL = "postgresql://db.internal:5432/payments"
    LOG_LEVEL    = "info"
    REGION       = "us-east-1"
  }

  health_check_path = "/healthz"

  # Debugging
  enable_execute_command = false

  # Logging
  log_retention_in_days = 90

  # Application-level IAM policies
  task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    aws_iam_policy.payment_secrets.arn,
  ]

  # Capacity strategy: prioritise Spot for cost savings
  default_capacity_provider_strategy = [
    { capacity_provider = "FARGATE",      weight = 1, base = 2 },
    { capacity_provider = "FARGATE_SPOT", weight = 3, base = 0 },
  ]

  tags = {
    Team        = "platform"
    CostCenter  = "eng-1234"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS Provider | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Project name prefix for all resources | `string` | — | ✅ |
| `environment` | Deployment environment (`dev`, `staging`, `production`) | `string` | — | ✅ |
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
| `capacity_providers` | Cluster capacity providers | `list(string)` | `["FARGATE", "FARGATE_SPOT"]` | ❌ |
| `default_capacity_provider_strategy` | Default capacity provider strategy | `list(object)` | See variables.tf | ❌ |
| `log_retention_in_days` | CloudWatch log retention | `number` | `30` | ❌ |
| `task_role_policy_arns` | Additional IAM policies for task role | `list(string)` | `[]` | ❌ |
| `allowed_cidr_blocks` | CIDR blocks allowed on container port | `list(string)` | `["10.0.0.0/8"]` | ❌ |
| `tags` | Additional tags for all resources | `map(string)` | `{}` | ❌ |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | ECS cluster ID |
| `cluster_arn` | ECS cluster ARN |
| `cluster_name` | ECS cluster name |
| `service_id` | ECS service ID |
| `service_name` | ECS service name |
| `task_definition_arn` | Task definition ARN (includes revision) |
| `task_definition_family` | Task definition family name |
| `task_definition_revision` | Latest task definition revision |
| `security_group_id` | Security group ID for ECS tasks |
| `task_execution_role_arn` | Task execution role ARN |
| `task_role_arn` | Task role ARN |
| `log_group_name` | CloudWatch log group name |

## Design Decisions

### Why separate Execution Role and Task Role?

Following the **principle of least privilege**:

- **Execution Role** — used by the ECS *agent* to pull images from ECR and push logs to CloudWatch. Scoped to infra operations only.
- **Task Role** — assumed by the *application container* at runtime. Receives only the permissions the app needs (S3, DynamoDB, etc.) via `task_role_policy_arns`.

### Why `lifecycle { ignore_changes = [desired_count] }`?

If you configure auto-scaling outside this module (e.g., via `aws_appautoscaling_target`), the actual running count will diverge from `desired_count`. Without `ignore_changes`, every `terraform plan` would show a diff and attempt to reset the count.

### Why Circuit Breaker with Rollback?

The deployment circuit breaker detects when new tasks fail to stabilise and **automatically rolls back** to the last healthy deployment. This prevents a bad image push from taking down the service.

## Security Considerations

- **No public IP** — Tasks are launched with `assign_public_ip = false`. Place them in private subnets with a NAT gateway for outbound access.
- **Scoped ingress** — The security group only allows traffic on the container port from `allowed_cidr_blocks`.
- **Full egress** — Required for ECR image pulls and CloudWatch API calls. Restrict further with VPC endpoints if needed.

## License

Internal use — Indico DevSecOps.
