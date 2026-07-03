# AWS CodePipeline Terraform Module

Production-grade Terraform module that provisions a fully configured AWS CodePipeline with GitHub source integration, CodeBuild, and optional ECS deployment.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CodePipeline                             │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │    Source     │───▶│    Build     │───▶│     Deploy       │   │
│  │   (GitHub)   │    │  (CodeBuild) │    │   (ECS - opt.)   │   │
│  └──────────────┘    └──────────────┘    └──────────────────┘   │
│         │                   │                     │             │
│         ▼                   ▼                     ▼             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │  CodeStar    │    │  CodeBuild   │    │   ECS Cluster    │   │
│  │  Connection  │    │   Project    │    │    / Service      │   │
│  └──────────────┘    └──────────────┘    └──────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              S3 Artifact Bucket                          │    │
│  │  (Versioned · Encrypted · Lifecycle-managed · Private)   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Features

- **3-stage pipeline**: Source (GitHub) → Build (CodeBuild) → Deploy (ECS)
- **Optional Deploy stage**: Disable for build-only / CI-only pipelines
- **Hardened S3 artifact bucket**: Versioning, AES256 encryption, public access block, lifecycle rules
- **Least-privilege IAM**: Scoped permissions for S3, CodeBuild, ECS, CodeStar, and IAM PassRole
- **Flexible resource provisioning**: Bring your own S3 bucket or CodeStar Connection, or let the module create them
- **Comprehensive tagging**: Default + custom tags on every resource

## Usage

### Full Pipeline (Source → Build → Deploy)

```hcl
module "pipeline" {
  source = "./modules/codepipeline"

  project_name           = "my-app"
  environment            = "production"
  source_repository      = "my-org/my-app"
  source_branch          = "main"
  codebuild_project_name = "my-app-production-build"
  ecs_cluster_name       = "my-app-production"
  ecs_service_name       = "my-app-api"

  tags = {
    Team = "platform"
  }
}
```

### Build-Only Pipeline (No Deploy)

```hcl
module "pipeline" {
  source = "./modules/codepipeline"

  project_name           = "my-lib"
  environment            = "dev"
  source_repository      = "my-org/my-lib"
  codebuild_project_name = "my-lib-dev-build"
  enable_deploy_stage    = false
}
```

### Using Existing Resources

```hcl
module "pipeline" {
  source = "./modules/codepipeline"

  project_name           = "my-app"
  environment            = "staging"
  source_repository      = "my-org/my-app"
  codebuild_project_name = "my-app-staging-build"
  ecs_cluster_name       = "my-app-staging"
  ecs_service_name       = "my-app-api"

  # Use existing S3 bucket instead of creating a new one
  create_s3_bucket = false
  existing_s3_bucket = "my-shared-artifacts-bucket"

  # Use existing CodeStar Connection
  create_codestar_connection      = false
  existing_codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/abc-123"
}
```

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.3   |
| aws       | >= 5.0   |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project, used as resource name prefix | `string` | — | ✅ |
| `environment` | Deployment environment (`dev`, `staging`, `production`) | `string` | — | ✅ |
| `source_repository` | GitHub repository in `owner/repo` format | `string` | — | ✅ |
| `source_branch` | Branch to track for source changes | `string` | `"main"` | ❌ |
| `detect_changes` | Auto-detect source changes and trigger pipeline | `bool` | `true` | ❌ |
| `codebuild_project_name` | Name of the CodeBuild project to use | `string` | — | ✅ |
| `enable_deploy_stage` | Include the ECS Deploy stage | `bool` | `true` | ❌ |
| `ecs_cluster_name` | ECS cluster name (required if deploy enabled) | `string` | `""` | ❌ |
| `ecs_service_name` | ECS service name (required if deploy enabled) | `string` | `""` | ❌ |
| `create_s3_bucket` | Create a new S3 artifact bucket | `bool` | `true` | ❌ |
| `existing_s3_bucket` | Existing S3 bucket name (if `create_s3_bucket = false`) | `string` | `""` | ❌ |
| `artifact_expiration_days` | Days before artifacts auto-expire (1–365) | `number` | `30` | ❌ |
| `create_codestar_connection` | Create a new CodeStar Connection | `bool` | `true` | ❌ |
| `existing_codestar_connection_arn` | Existing CodeStar Connection ARN | `string` | `""` | ❌ |
| `codestar_provider_type` | Source provider type for CodeStar | `string` | `"GitHub"` | ❌ |
| `tags` | Additional tags for all resources | `map(string)` | `{}` | ❌ |

## Outputs

| Name | Description |
|------|-------------|
| `pipeline_id` | The ID of the CodePipeline |
| `pipeline_arn` | The ARN of the CodePipeline |
| `pipeline_name` | The name of the CodePipeline |
| `pipeline_role_arn` | The ARN of the pipeline's IAM role |
| `pipeline_role_name` | The name of the pipeline's IAM role |
| `artifact_bucket_name` | The name of the S3 artifact bucket |
| `artifact_bucket_arn` | The ARN of the S3 artifact bucket (null if externally provided) |
| `codestar_connection_arn` | The ARN of the CodeStar Connection |
| `codestar_connection_status` | The status of the CodeStar Connection (null if externally provided) |

## Post-Deployment Steps

> [!IMPORTANT]
> **CodeStar Connection requires manual activation.** After `terraform apply`, the CodeStar Connection will be in `PENDING` status. You must complete the OAuth handshake in the [AWS Console → Developer Tools → Connections](https://console.aws.amazon.com/codesuite/settings/connections) to activate it.

> [!NOTE]
> **CodeBuild `imagedefinitions.json`**: The Deploy stage expects an `imagedefinitions.json` file in the build output. Your CodeBuild buildspec must produce this file. Example:
> ```json
> [
>   {
>     "name": "my-container",
>     "imageUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest"
>   }
> ]
> ```

## Security Considerations

- **Least-privilege IAM**: The pipeline role has only the permissions it needs. ECS and CodeBuild actions are scoped to specific resources or regions.
- **Encryption at rest**: S3 artifacts are encrypted with AES256 (SSE-S3) by default.
- **No public access**: All public access settings on the S3 bucket are explicitly blocked.
- **IAM PassRole restriction**: Limited to ECS Tasks and CodeBuild service principals only.
- **Artifact lifecycle**: Old artifacts are automatically cleaned up to reduce attack surface and cost.
