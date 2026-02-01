output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "alarm_arns" {
  description = "ARNs of all CloudWatch alarms"
  value = {
    ecs_high_cpu      = aws_cloudwatch_metric_alarm.ecs_high_cpu.arn
    ecs_high_memory   = aws_cloudwatch_metric_alarm.ecs_high_memory.arn
    alb_5xx_errors    = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
    sqs_queue_depth   = aws_cloudwatch_metric_alarm.sqs_queue_depth.arn
    sqs_message_age   = aws_cloudwatch_metric_alarm.sqs_message_age.arn
    alb_unhealthy     = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn
  }
}
