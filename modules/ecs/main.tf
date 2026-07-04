################################################################################
# Data Sources
################################################################################

data "aws_region" "current" {}

################################################################################
# Local Values
################################################################################

locals {
  # Canonical resource name prefix used across all resources
  name_prefix = "${var.project_name}-${var.environment}"

  # Standard tags merged onto every resource
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "ecs"
  })

  # Container name derived from project — used in task definition & service config
  container_name = "${local.name_prefix}-container"
}

################################################################################
# ECS Cluster
#
# Container Insights enabled for metrics & log collection.
# Capacity providers configured for Fargate / Fargate Spot cost optimization.
################################################################################

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}

################################################################################
# CloudWatch Log Group
#
# Centralized log destination for all container stdout/stderr.
# Retention is configurable; defaults to 30 days.
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_in_days

  tags = merge(local.common_tags, {
    Name = "/ecs/${local.name_prefix}"
  })
}

################################################################################
# IAM – Task Execution Role
#
# Grants the ECS agent permissions to:
#   • Pull container images from ECR
#   • Push logs to CloudWatch
# Attached policy: AmazonECSTaskExecutionRolePolicy (AWS managed)
################################################################################

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# IAM – Task Role
#
# Grants the *application* inside the container its runtime permissions
# (e.g., access to S3, DynamoDB, SQS).
# Additional policies can be attached via var.task_role_policy_arns.
################################################################################

resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-role"
  })
}

resource "aws_iam_role_policy_attachment" "task_additional" {
  count = length(var.task_role_policy_arns)

  role       = aws_iam_role.task.name
  policy_arn = var.task_role_policy_arns[count.index]
}

################################################################################
# Security Group
#
# Ingress: allows traffic on the container port from configurable CIDR blocks.
# Egress:  allows all outbound traffic (required for image pulls, API calls).
################################################################################

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Security group for ECS tasks in ${local.name_prefix}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-tasks-sg"
  })
}

resource "aws_security_group_rule" "ingress" {
  description       = "Allow inbound traffic on container port ${var.container_port}"
  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}

################################################################################
# ECS Task Definition
#
# Fargate-compatible task definition with:
#   • Configurable CPU / memory
#   • Container health check
#   • Environment variable injection
#   • CloudWatch log driver
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # Inject environment variables from the provided map
      environment = [
        for key, value in var.container_environment : {
          name  = key
          value = value
        }
      ]

      # Container-level health check
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Ship all stdout/stderr to CloudWatch via the awslogs driver
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-task"
  })
}

################################################################################
# ECS Service
#
# Runs and maintains the desired count of task instances.
# Features:
#   • Deployment circuit breaker with automatic rollback
#   • Configurable min/max healthy percentages for rolling deploys
#   • Optional ALB/NLB target group attachment
#   • ECS Exec support for interactive debugging
################################################################################

resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Enable ECS Exec (aws ecs execute-command) for debugging
  enable_execute_command = var.enable_execute_command

  # Rolling deployment configuration
  deployment_minimum_healthy_percent = var.min_healthy_percent
  deployment_maximum_percent         = var.max_percent

  # Circuit breaker: automatically rolls back failed deployments
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Fargate tasks require awsvpc networking
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # Conditionally attach to a load balancer target group
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [var.target_group_arn] : []
    content {
      target_group_arn = load_balancer.value
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  # Ensure the IAM roles and task definition exist before creating the service
  depends_on = [
    aws_iam_role_policy_attachment.task_execution,
    aws_ecs_task_definition.this,
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service"
  })

  # Ignore changes to desired_count and task_definition so that auto-scaling
  # and CodePipeline deployments do not cause conflicts or rollbacks in Terraform.
  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
    ]
  }
}
