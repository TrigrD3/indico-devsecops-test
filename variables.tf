# =============================================================================
# Root Configuration - Input Variables
# =============================================================================

# --- AWS / General ---
variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Name of the project. Used as a prefix for all resource names."
  type        = string
  default     = "container-app"
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)."
  type        = string
  default     = "dev"
}

# --- Pre-existing Network (Optional) ---
variable "vpc_id" {
  description = "VPC ID to deploy resources into. If not specified, a new VPC will be created."
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB. Required if specifying an existing vpc_id."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks. Required if specifying an existing vpc_id."
  type        = list(string)
  default     = []
}

# --- Dynamic Network Settings (Used if vpc_id is null) ---
variable "vpc_cidr" {
  description = "The CIDR block for the created VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (min 2 for ALB)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (min 2 for Fargate)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# --- Container Configuration ---
variable "container_image" {
  description = "Docker image for the application container."
  type        = string
  default     = "nginxdemos/hello:latest"
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU units for the Fargate task."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MiB) for the Fargate task."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to keep running."
  type        = number
  default     = 2
}

# --- Source Configuration (CI/CD) ---
variable "source_repository" {
  description = "GitHub repository in 'owner/repo' format."
  type        = string
}

variable "source_branch" {
  description = "Git branch that triggers the pipeline."
  type        = string
  default     = "main"
}

# --- TLS Configuration (ALB) ---
variable "enable_https" {
  description = "Enable HTTPS on ALB (requires certificate_arn)."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener."
  type        = string
  default     = ""
}

# --- API Container Configuration (Second Service) ---
variable "api_container_image" {
  description = "Docker image for the backend API container."
  type        = string
  default     = "nginxdemos/hello:latest"
}

variable "api_container_port" {
  description = "Port the backend API container listens on."
  type        = number
  default     = 8080
}

variable "api_cpu" {
  description = "CPU units for the backend API Fargate task."
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Memory (MiB) for the backend API Fargate task."
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Number of ECS tasks to keep running for the API service."
  type        = number
  default     = 2
}

# --- Tags ---
variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
