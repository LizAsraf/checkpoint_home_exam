output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "service1_name" {
  description = "Name of ECS service 1"
  value       = aws_ecs_service.service1.name
}

output "service2_name" {
  description = "Name of ECS service 2"
  value       = aws_ecs_service.service2.name
}

output "service1_task_definition_arn" {
  description = "ARN of service 1 task definition"
  value       = aws_ecs_task_definition.service1.arn
}

output "service2_task_definition_arn" {
  description = "ARN of service 2 task definition"
  value       = aws_ecs_task_definition.service2.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB for CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics"
  value       = aws_lb_target_group.service1.arn_suffix
}
