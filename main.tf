# =============================================================================
# Root Configuration - Module Composition
# =============================================================================
# Wires the VPC, ALB, ECS, CodeBuild, and CodePipeline modules together.
# Supports dual-mode deployment:
#   1. New VPC Mode: Creates a new VPC dynamically when vpc_id is null/empty.
#   2. Existing VPC Mode: Deploys into pre-existing network infrastructure.
# =============================================================================

locals {
  create_vpc         = var.vpc_id == null || var.vpc_id == ""
  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnet_ids : var.public_subnet_ids
  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnet_ids : var.private_subnet_ids
}

# --- Dynamic VPC Module (Conditional) ---
module "vpc" {
  count  = local.create_vpc ? 1 : 0
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# --- ALB Module ---
module "alb" {
  source = "./modules/alb"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = local.vpc_id
  subnet_ids                 = local.public_subnet_ids
  container_port             = var.container_port
  enable_https               = var.enable_https
  certificate_arn            = var.certificate_arn
  health_check_path          = "/health"
  enable_deletion_protection = false
  tags                       = var.tags
}

# --- ECS Module ---
module "ecs" {
  source = "./modules/ecs"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = local.vpc_id
  subnet_ids             = local.private_subnet_ids
  container_image        = var.container_image
  container_port         = var.container_port
  cpu                    = var.cpu
  memory                 = var.memory
  desired_count          = var.desired_count
  target_group_arn       = module.alb.target_group_arn
  allowed_cidr_blocks    = ["10.0.0.0/8"]
  enable_execute_command = true
  tags                   = var.tags
}

# --- CodeBuild Module ---
module "codebuild" {
  source = "./modules/codebuild"

  project_name    = var.project_name
  environment     = var.environment
  description     = "Build project for ${var.project_name}"
  privileged_mode = true
  source_type     = "CODEPIPELINE"
  artifact_type   = "CODEPIPELINE"
  s3_bucket_arn   = module.codepipeline.artifact_bucket_arn

  environment_variables = [
    {
      name  = "REPOSITORY_URI"
      value = var.container_image
      type  = "PLAINTEXT"
    },
    {
      name  = "CONTAINER_NAME"
      value = "${var.project_name}-${var.environment}"
      type  = "PLAINTEXT"
    },
    {
      name  = "CONTAINER_PORT"
      value = tostring(var.container_port)
      type  = "PLAINTEXT"
    }
  ]

  tags = var.tags
}

# --- CodePipeline Module ---
module "codepipeline" {
  source = "./modules/codepipeline"

  project_name           = var.project_name
  environment            = var.environment
  source_repository      = var.source_repository
  source_branch          = var.source_branch
  codebuild_project_name = module.codebuild.project_name
  ecs_cluster_name       = module.ecs.cluster_name
  ecs_service_name       = module.ecs.service_name
  enable_deploy_stage    = true
  tags                   = var.tags
}
