# VPC Terraform Module

This module provisions a production-ready **AWS VPC (Virtual Private Cloud)** featuring a 2-tier subnet architecture (Public and Private Subnets), isolated route tables, an Internet Gateway, and a shared NAT Gateway.

## Architecture

```
                    Internet
                       │
                       ▼
               ┌───────────────┐
               │   VPC (CIDR)  │
               └───────┬───────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│ Public Subnets  │         │ Private Subnets │
│ (ALB, NAT GW)   │         │ (ECS Fargate)   │
└────────┬────────┘         └────────┬────────┘
         │                           │
         ▼                           ▼
  Internet Gateway              NAT Gateway
         ▲                           │
         └─────────(egress)──────────┘
```

## Features

- **2-Tier Architecture**: Public subnets host edge routing resources (ALB, NAT GW), and private subnets contain core services (ECS tasks).
- **Multiple Availability Zones (AZs)**: Spreads subnets across multiple AZs automatically for high availability and fault tolerance.
- **Cost-Optimized NAT**: Leverages a single shared NAT Gateway across private subnets to reduce standard AWS idle charge costs.
- **Observability**: DNS resolution and hostnames enabled within the private namespaces.
- **Consistent Tagging**: Dynamically merges standard user tags with module identity tags.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name = "payments"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Prefix for naming resources | `string` | n/a | yes |
| `environment` | Environment identifier (dev/staging/production) | `string` | n/a | yes |
| `vpc_cidr` | CIDR block allocated to the VPC namespace | `string` | `"10.0.0.0/16"` | no |
| `public_subnet_cidrs` | Subnet CIDR blocks to assign to public paths | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | no |
| `private_subnet_cidrs`| Subnet CIDR blocks to assign to private paths | `list(string)` | `["10.0.10.0/24", "10.0.11.0/24"]` | no |
| `availability_zones` | Specific AZs to bind. Auto-computed if empty. | `list(string)` | `[]` | no |
| `enable_dns_hostnames`| Toggles DNS hostnames support within the VPC | `bool` | `true` | no |
| `enable_dns_support`  | Toggles DNS resolution services in the VPC | `bool` | `true` | no |
| `tags` | Custom resource tags map | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | Unique ID of the created VPC |
| `vpc_cidr_block` | Complete CIDR block of the VPC |
| `public_subnet_ids` | List of public subnet IDs (used for ALB) |
| `private_subnet_ids`| List of private subnet IDs (used for ECS tasks) |
| `nat_gateway_public_ip`| EIP allocated to the egress NAT Gateway |
