output "parameter_name" {
  description = "Name of the SSM parameter"
  value       = aws_ssm_parameter.api_token.name
}

output "parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = aws_ssm_parameter.api_token.arn
}

output "api_token" {
  description = "The generated API token (sensitive)"
  value       = random_password.api_token.result
  sensitive   = true
}
