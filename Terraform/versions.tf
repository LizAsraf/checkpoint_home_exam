terraform {
  required_version = ">= 1.0.0"

  # Using local backend for Checkpoint account
  # For production, configure S3 backend in their account
  # backend "s3" {
  #   bucket         = "your-checkpoint-terraform-bucket"
  #   key            = "checkpoint-exam/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
