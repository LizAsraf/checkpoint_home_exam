variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS instances"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS instances"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "ecs_instance_profile_arn" {
  description = "ARN of the IAM instance profile for ECS instances"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role (for application permissions)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS instances"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

variable "desired_capacity" {
  description = "Desired number of ECS instances"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 2
}

variable "service1_image" {
  description = "Docker image for microservice 1 (REST API)"
  type        = string
  default     = "amazon/amazon-ecs-sample"  # Placeholder
}

variable "service2_image" {
  description = "Docker image for microservice 2 (SQS worker)"
  type        = string
  default     = "amazon/amazon-ecs-sample"  # Placeholder
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter containing API token"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
