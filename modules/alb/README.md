# ALB Terraform Module

Production-grade AWS Application Load Balancer module designed for Fargate workloads with optional HTTPS termination.

---

## Architecture

```
Internet
    │
    ▼
┌──────────────────────────────────┐
│  Security Group (HTTP/HTTPS in)  │
└──────────────┬───────────────────┘
               │
    ┌──────────▼──────────┐
    │  Application Load   │
    │     Balancer         │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐    ┌──────────────────────┐
    │   HTTP Listener     │    │   HTTPS Listener      │
    │   (port 80)         │    │   (port 443, optional)│
    │   redirect or fwd   │    │   TLS termination     │
    └──────────┬──────────┘    └──────────┬───────────┘
               │                          │
               └──────────┬───────────────┘
                          │
               ┌──────────▼──────────┐
               │   Target Group      │
               │   (IP type/Fargate) │
               │   + Health Checks   │
               └─────────────────────┘
```

## Usage

### HTTP Only (Development)

```hcl
module "alb" {
  source = "./modules/alb"

  project_name = "myapp"
  environment  = "dev"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids

  health_check_path = "/api/health"
  container_port    = 8080

  tags = {
    Team = "platform"
  }
}
```

### HTTPS Enabled (Production)

```hcl
module "alb" {
  source = "./modules/alb"

  project_name = "myapp"
  environment  = "production"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids

  enable_https   = true
  certificate_arn = aws_acm_certificate.main.arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  health_check_path          = "/api/health"
  container_port             = 8080
  enable_deletion_protection = true

  allowed_cidr_blocks = ["10.0.0.0/8"]

  tags = {
    Team        = "platform"
    CostCenter  = "engineering"
  }
}
```

### Internal ALB (Private Services)

```hcl
module "alb" {
  source = "./modules/alb"

  project_name = "internal-api"
  environment  = "production"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  internal            = true
  allowed_cidr_blocks = ["10.0.0.0/8"]
  container_port      = 3000

  tags = {
    Team = "backend"
  }
}
```

### Connecting to an ECS Service

```hcl
resource "aws_ecs_service" "app" {
  # ...

  load_balancer {
    target_group_arn = module.alb.target_group_arn
    container_name   = "app"
    container_port   = 8080
  }
}

# Allow ALB to reach the ECS tasks
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = aws_security_group.ecs_tasks.id
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Project name used as resource name prefix | `string` | — | ✅ |
| `environment` | Deployment environment (`dev`, `staging`, `production`) | `string` | — | ✅ |
| `vpc_id` | VPC ID for ALB and security group | `string` | — | ✅ |
| `subnet_ids` | Subnet IDs (min 2, across AZs) | `list(string)` | — | ✅ |
| `internal` | Create internal (private) ALB | `bool` | `false` | |
| `enable_https` | Enable HTTPS listener + HTTP→HTTPS redirect | `bool` | `false` | |
| `certificate_arn` | ACM certificate ARN (required if `enable_https = true`) | `string` | `""` | |
| `ssl_policy` | TLS negotiation policy | `string` | `ELBSecurityPolicy-TLS13-1-2-2021-06` | |
| `health_check_path` | HTTP path for health checks | `string` | `/health` | |
| `health_check_interval` | Seconds between health checks | `number` | `30` | |
| `health_check_timeout` | Health check timeout in seconds | `number` | `5` | |
| `healthy_threshold` | Consecutive successes to mark healthy | `number` | `3` | |
| `unhealthy_threshold` | Consecutive failures to mark unhealthy | `number` | `3` | |
| `health_check_matcher` | HTTP status codes for healthy response | `string` | `"200"` | |
| `deregistration_delay` | Drain time before target removal (seconds) | `number` | `30` | |
| `container_port` | Port the target container listens on | `number` | `80` | |
| `idle_timeout` | ALB idle connection timeout (seconds) | `number` | `60` | |
| `enable_deletion_protection` | Prevent accidental ALB deletion | `bool` | `false` | |
| `allowed_cidr_blocks` | CIDRs allowed to reach the ALB | `list(string)` | `["0.0.0.0/0"]` | |
| `tags` | Additional resource tags | `map(string)` | `{}` | |

## Outputs

| Name | Description |
|------|-------------|
| `alb_id` | ALB resource ID |
| `alb_arn` | ALB ARN (for WAF, cross-stack refs) |
| `alb_dns_name` | ALB DNS name (for CNAME / CloudFront origin) |
| `alb_zone_id` | ALB hosted zone ID (for Route 53 alias records) |
| `target_group_id` | Target group ID |
| `target_group_arn` | Target group ARN (for ECS service binding) |
| `target_group_name` | Target group name |
| `http_listener_arn` | HTTP listener ARN |
| `https_listener_arn` | HTTPS listener ARN (empty string when disabled) |
| `security_group_id` | ALB security group ID (reference in ECS task SG) |

---

## Security Features

| Feature | Implementation |
|---------|---------------|
| **TLS 1.3 by default** | `ELBSecurityPolicy-TLS13-1-2-2021-06` enforces TLS 1.3 with 1.2 fallback |
| **HTTP → HTTPS redirect** | Automatic 301 redirect when `enable_https = true` |
| **Invalid header rejection** | `drop_invalid_header_fields = true` mitigates request-smuggling |
| **Deletion protection** | Configurable; recommended `true` for production |
| **Scoped ingress** | `allowed_cidr_blocks` restricts inbound traffic |
| **Input validation** | All critical variables have `validation` blocks |

---

## Requirements

| Dependency | Version |
|------------|---------|
| Terraform  | >= 1.0  |
| AWS Provider | >= 4.0 |

## License

Internal module — proprietary.
