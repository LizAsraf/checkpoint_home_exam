resource "random_password" "api_token" {
  length  = 32
  special = true
}

resource "aws_ssm_parameter" "api_token" {
  name        = "/${var.project_name}/api-token"
  description = "API token"
  type        = "SecureString"
  value       = random_password.api_token.result

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-api-token-${var.environment}"
    }
  )
}
