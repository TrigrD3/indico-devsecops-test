# =============================================================================
# ALB Module - Main Resources
# =============================================================================
# Creates a production-grade Application Load Balancer stack:
#   1. Security Group      — Controls ingress (HTTP/HTTPS) and egress traffic
#   2. Application LB      — Internet-facing or internal, with security hardening
#   3. Target Group         — IP-type targets for Fargate, with health checks
#   4. HTTP Listener        — Redirects to HTTPS when TLS is enabled, else forwards
#   5. HTTPS Listener       — TLS termination with ACM cert (conditional)
# =============================================================================

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
# Centralises naming and tagging so every resource stays consistent.

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

# =============================================================================
# 1. Security Group
# =============================================================================
# Dedicated SG for the ALB. Ingress is scoped to the caller-supplied CIDR
# blocks on HTTP (80) and HTTPS (443). Egress is unrestricted so the ALB can
# reach targets in any subnet/port.

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ${local.name_prefix} ALB — allows HTTP/HTTPS ingress"
  vpc_id      = var.vpc_id

  # --- Ingress: HTTP (port 80) ---
  ingress {
    description = "Allow HTTP traffic from permitted CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # --- Ingress: HTTPS (port 443) ---
  ingress {
    description = "Allow HTTPS traffic from permitted CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # --- Egress: all traffic ---
  # The ALB must be able to reach targets in the VPC on any port.
  egress {
    description = "Allow all outbound traffic to targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# 2. Application Load Balancer
# =============================================================================
# Key security hardening:
#   - drop_invalid_header_fields: Mitigates HTTP request-smuggling attacks.
#   - enable_deletion_protection: Prevents accidental destroy in production.
#   - idle_timeout: Tunable to match application keep-alive behaviour.

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  idle_timeout               = var.idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true # Security: reject malformed headers

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# =============================================================================
# 3. Target Group
# =============================================================================
# Uses target_type = "ip" for compatibility with AWS Fargate (awsvpc networking).
# The health check is fully configurable to match the application's readiness
# endpoint and timing characteristics.

resource "aws_lb_target_group" "this" {
  name                 = "${local.name_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = var.health_check_matcher
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })

  # Ensure a new TG is created before the old one is destroyed during updates
  # to avoid downtime when name or port changes force a replacement.
  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# 4. HTTP Listener (port 80)
# =============================================================================
# Behaviour depends on whether HTTPS is enabled:
#   - HTTPS enabled  → 301 redirect all HTTP traffic to HTTPS (best practice)
#   - HTTPS disabled → Forward traffic directly to the target group

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # When HTTPS is enabled, redirect HTTP → HTTPS with a 301 (permanent).
  # When HTTPS is disabled, forward directly to the target group.
  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-listener"
  })
}

# =============================================================================
# 5. HTTPS Listener (port 443) — Conditional
# =============================================================================
# Only created when var.enable_https is true.
# Terminates TLS using the supplied ACM certificate and forwards decrypted
# traffic to the target group over HTTP (offloading TLS from the application).

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-https-listener"
  })
}
