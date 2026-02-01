output "service1_repository_url" {
  description = "URL of the ECR repository for service1"
  value       = aws_ecr_repository.service1.repository_url
}

output "service2_repository_url" {
  description = "URL of the ECR repository for service2"
  value       = aws_ecr_repository.service2.repository_url
}

output "service1_repository_arn" {
  description = "ARN of the ECR repository for service1"
  value       = aws_ecr_repository.service1.arn
}

output "service2_repository_arn" {
  description = "ARN of the ECR repository for service2"
  value       = aws_ecr_repository.service2.arn
}
