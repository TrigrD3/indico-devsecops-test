# AWS CodeBuild Terraform Module

Production-ready Terraform module for provisioning an AWS CodeBuild project with an IAM service role (least-privilege) and a dedicated CloudWatch Log Group.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  CodeBuild Project                   │
│                                                     │
│  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Environment  │  │  Source  │  │   Artifacts   │  │
│  │ (Docker/AL2) │  │(Pipeline)│  │  (Pipeline)   │  │
│  └─────────────┘  └──────────┘  └───────────────┘  │
│                                                     │
│  ┌─────────────┐  ┌──────────────────────────────┐  │
│  │   Cache     │  │     Environment Variables     │  │
│  │(Docker/Src) │  │ PLAINTEXT | SSM | SecretsMan │  │
│  └─────────────┘  └──────────────────────────────┘  │
│                                                     │
│  ┌──────────────────┐  ┌─────────────────────────┐  │
│  │  VPC Config (opt) │  │  CloudWatch Logs       │  │
│  │  Subnets / SGs    │  │  /aws/codebuild/...    │  │
│  └──────────────────┘  └─────────────────────────┘  │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│              IAM Service Role                        │
│                                                     │
│  ✓ CloudWatch Logs    (always)                      │
│  ✓ S3 Artifacts       (always)                      │
│  ✓ ECR Pull/Push      (when ecr_repository_arns)    │
│  ✓ Secrets Manager    (when enabled/detected)        │
│  ✓ Parameter Store    (when enabled/detected)        │
│  ✓ VPC ENI Management (when vpc_config)              │
└─────────────────────────────────────────────────────┘
```

## Usage

### Minimal Example (CodePipeline Integration)

```hcl
module "codebuild" {
  source = "./modules/codebuild"

  project_name = "my-app-build"
  environment  = "dev"
  description  = "Build and test my-app"
  s3_bucket_arn = "arn:aws:s3:::my-pipeline-artifacts-bucket"
}
```

### Full Example (Docker Build with ECR Push + VPC Access)

```hcl
module "codebuild" {
  source = "./modules/codebuild"

  project_name  = "my-app-build"
  environment   = "production"
  description   = "Build Docker image and push to ECR"
  build_timeout = 60

  # Build environment
  compute_type     = "BUILD_GENERAL1_MEDIUM"
  image            = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  environment_type = "LINUX_CONTAINER"
  privileged_mode  = true

  # Source
  source_type = "CODEPIPELINE"
  buildspec   = "ci/buildspec.yml"

  # Artifacts
  artifact_type = "CODEPIPELINE"

  # ECR repositories for Docker push
  ecr_repository_arns = [
    "arn:aws:ecr:us-east-1:123456789012:repository/my-app",
  ]

  # Environment variables
  environment_variables = [
    {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
      type  = "PLAINTEXT"
    },
    {
      name  = "IMAGE_REPO_NAME"
      value = "my-app"
      type  = "PLAINTEXT"
    },
    {
      name  = "DOCKER_PASSWORD"
      value = "/codebuild/docker-password"
      type  = "PARAMETER_STORE"
    },
  ]

  # VPC access for private resources
  vpc_config = {
    vpc_id             = "vpc-0123456789abcdef0"
    subnets            = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }

  # Logging
  log_retention_in_days = 365
  log_group_kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/my-key-id"

  # Concurrency
  concurrent_build_limit = 3

  # IAM
  s3_bucket_arn = "arn:aws:s3:::my-pipeline-artifacts-bucket"

  tags = {
    Team    = "platform"
    CostCenter = "engineering"
  }
}
```

### Standalone Build (GitHub Source, No Pipeline)

```hcl
module "codebuild_standalone" {
  source = "./modules/codebuild"

  project_name = "my-app-ci"
  environment  = "dev"
  description  = "CI build triggered by GitHub webhook"

  source_type     = "GITHUB"
  source_location = "https://github.com/my-org/my-repo.git"
  artifact_type   = "NO_ARTIFACTS"
  buildspec       = "buildspec.yml"

  s3_bucket_arn = "arn:aws:s3:::my-build-cache-bucket"

  tags = {
    Team = "backend"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Name of the CodeBuild project | `string` | — | ✅ |
| `environment` | Deployment environment (`dev`, `staging`, `production`) | `string` | — | ✅ |
| `s3_bucket_arn` | ARN of the S3 bucket for artifacts | `string` | — | ✅ |
| `description` | Project description | `string` | `"Managed by Terraform"` | ❌ |
| `build_timeout` | Build timeout in minutes (5–480) | `number` | `30` | ❌ |
| `queued_timeout` | Queue timeout in minutes (5–480) | `number` | `60` | ❌ |
| `concurrent_build_limit` | Max concurrent builds (`null` = unlimited) | `number` | `1` | ❌ |
| `compute_type` | Build compute type | `string` | `"BUILD_GENERAL1_SMALL"` | ❌ |
| `image` | Build environment Docker image | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | ❌ |
| `environment_type` | Build environment type | `string` | `"LINUX_CONTAINER"` | ❌ |
| `privileged_mode` | Enable Docker-in-Docker | `bool` | `true` | ❌ |
| `image_pull_credentials_type` | Image pull credential type | `string` | `"CODEBUILD"` | ❌ |
| `source_type` | Source provider type | `string` | `"CODEPIPELINE"` | ❌ |
| `source_location` | Source location (URL/path) | `string` | `null` | ❌ |
| `buildspec` | Buildspec file path or inline YAML | `string` | `null` | ❌ |
| `artifact_type` | Artifact output type | `string` | `"CODEPIPELINE"` | ❌ |
| `environment_variables` | List of env var objects (`name`, `value`, `type`) | `list(object)` | `[]` | ❌ |
| `vpc_config` | VPC configuration object | `object` | `null` | ❌ |
| `ecr_repository_arns` | ECR repo ARNs for pull/push access | `list(string)` | `[]` | ❌ |
| `enable_secrets_manager` | Grant Secrets Manager read access | `bool` | `false` | ❌ |
| `enable_parameter_store` | Grant SSM Parameter Store read access | `bool` | `false` | ❌ |
| `log_retention_in_days` | CloudWatch log retention (0 = indefinite) | `number` | `90` | ❌ |
| `log_group_kms_key_id` | KMS key ARN for log encryption | `string` | `null` | ❌ |
| `tags` | Additional tags for all resources | `map(string)` | `{}` | ❌ |

## Outputs

| Name | Description |
|------|-------------|
| `project_id` | CodeBuild project ID |
| `project_arn` | CodeBuild project ARN |
| `project_name` | CodeBuild project name |
| `service_role_arn` | IAM service role ARN |
| `service_role_name` | IAM service role name |
| `log_group_name` | CloudWatch Log Group name |
| `log_group_arn` | CloudWatch Log Group ARN |

## IAM Permissions Strategy

This module follows the **principle of least privilege**:

| Permission | Condition | Scope |
|-----------|-----------|-------|
| CloudWatch Logs | Always granted | Specific log group only |
| S3 | Always granted | Specific bucket + objects only |
| ECR Auth Token | When `ecr_repository_arns` provided | `*` (required by AWS) |
| ECR Pull/Push | When `ecr_repository_arns` provided | Specific repositories only |
| Secrets Manager | When enabled or detected in env vars | Current account/region |
| SSM Parameter Store | When enabled or detected in env vars | Current account/region |
| VPC (EC2 ENI) | When `vpc_config` provided | Scoped to specific subnets |

> **Note:** Secrets Manager and Parameter Store permissions are **auto-detected** from `environment_variables` types. If any variable uses `SECRETS_MANAGER` type, the corresponding IAM statement is automatically included — no need to set `enable_secrets_manager = true` manually (though you can for explicit control).

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.3 |
| AWS Provider | >= 5.0 |

## License

This module is part of the indico-devsecops infrastructure. Internal use only.
