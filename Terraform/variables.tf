variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "checkpoint-exam"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ECS Configuration
variable "ecs_instance_type" {
  description = "EC2 instance type for ECS instances. t2.micro is free tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "ecs_desired_capacity" {
  description = "Desired number of ECS instances"
  type        = number
  default     = 1
}

variable "ecs_min_size" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 1
}

variable "ecs_max_size" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 2
}

# Microservice images
variable "service1_image" {
  description = "Docker image for microservice 1 (REST API). Update after building."
  type        = string
  default     = "amazon/amazon-ecs-sample"
}

variable "service2_image" {
  description = "Docker image for microservice 2 (SQS worker). Update after building."
  type        = string
  default     = "amazon/amazon-ecs-sample"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
