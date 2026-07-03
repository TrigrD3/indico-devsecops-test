# =============================================================================
# VPC Module - Outputs
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC created."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC created."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ip" {
  description = "The public Elastic IP address associated with the NAT Gateway."
  value       = aws_eip.nat.public_ip
}
