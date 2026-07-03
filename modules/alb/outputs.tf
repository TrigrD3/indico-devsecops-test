# =============================================================================
# ALB Module - Outputs
# =============================================================================
# Exposes resource attributes needed by consuming modules (e.g., ECS service,
# Route 53 alias records, CloudFront origins, WAF associations).
# =============================================================================

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------

output "alb_id" {
  description = "The ID of the Application Load Balancer."
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer. Use for WAF associations or cross-stack references."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB. Use as a CNAME target or CloudFront origin."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB. Required for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

# -----------------------------------------------------------------------------
# Target Group
# -----------------------------------------------------------------------------

output "target_group_id" {
  description = "The ID of the target group."
  value       = aws_lb_target_group.this.id
}

output "target_group_arn" {
  description = "The ARN of the target group. Pass to ECS service or Auto Scaling group."
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "The name of the target group."
  value       = aws_lb_target_group.this.name
}

# -----------------------------------------------------------------------------
# Listeners
# -----------------------------------------------------------------------------

output "http_listener_arn" {
  description = "The ARN of the HTTP listener (port 80)."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener (port 443). Empty string when HTTPS is disabled."
  value       = try(aws_lb_listener.https[0].arn, "")
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

output "security_group_id" {
  description = "The ID of the ALB security group. Reference in ECS task SG rules to allow ALB → container traffic."
  value       = aws_security_group.alb.id
}
