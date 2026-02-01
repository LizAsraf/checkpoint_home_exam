# AWS Provider - uses environment variables for credentials
# Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY before running terraform

provider "aws" {
  region = var.aws_region
  # profile removed - will use environment variables

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
