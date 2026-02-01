aws_region   = "us-east-1"
environment  = "dev"
project_name = "checkpoint-exam"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# ECS - Free Tier Configuration
ecs_instance_type    = "t2.micro"  # Free tier eligible (750 hrs/month)
ecs_desired_capacity = 1
ecs_min_size         = 1
ecs_max_size         = 2

# Microservice images (update after building)
service1_image = "amazon/amazon-ecs-sample"
service2_image = "amazon/amazon-ecs-sample"

tags = {
  Owner   = "DevOps Team"
  Purpose = "DevOps Home Exam"
}
