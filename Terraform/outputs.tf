output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

# ECS outputs
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - use this to access the API"
  value       = module.ecs.alb_dns_name
}

output "service1_name" {
  description = "Name of microservice 1 (REST API)"
  value       = module.ecs.service1_name
}

output "service2_name" {
  description = "Name of microservice 2 (SQS worker)"
  value       = module.ecs.service2_name
}

# SQS outputs
output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = module.sqs.queue_arn
}

output "sqs_queue_name" {
  description = "Name of the SQS queue"
  value       = module.sqs.queue_name
}

# S3 outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for messages"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

# SSM outputs
output "ssm_parameter_name" {
  description = "Name of the SSM parameter containing the API token"
  value       = module.ssm.parameter_name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = module.ssm.parameter_arn
}

output "api_token" {
  description = "The generated API token for testing (sensitive - use: terraform output -raw api_token)"
  value       = module.ssm.api_token
  sensitive   = true
}

# ECR outputs
output "ecr_service1_url" {
  description = "ECR repository URL for service1"
  value       = module.ecr.service1_repository_url
}

output "ecr_service2_url" {
  description = "ECR repository URL for service2"
  value       = module.ecr.service2_repository_url
}

# Monitoring outputs (only available when enable_monitoring = true)
output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.enable_monitoring ? module.monitoring[0].dashboard_name : null
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = var.enable_monitoring ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring[0].dashboard_name}" : null
}
