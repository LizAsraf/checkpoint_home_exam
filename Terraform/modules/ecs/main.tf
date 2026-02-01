# ECS Cluster with EC2 Launch Type (Free Tier eligible)

# Get latest ECS-optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "disabled"  # Disabled to stay free tier
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cluster-${var.environment}"
    }
  )
}

# Launch Template for EC2 instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = var.ecs_instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ecs_security_group_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_TASK_IAM_ROLE=true" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-ecs-instance-${var.environment}"
      }
    )
  }

  tags = var.tags
}

# Auto Scaling Group for ECS instances
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg-${var.environment}"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-capacity-provider-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = var.tags
}

# Associate Capacity Provider with Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-alb-${var.environment}"
    }
  )
}

# ALB Target Group for Microservice 1
resource "aws_lb_target_group" "service1" {
  name        = "${var.project_name}-svc1-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = var.tags
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service1.arn
  }

  tags = var.tags
}

# CloudWatch Log Groups for services
resource "aws_cloudwatch_log_group" "service1" {
  name              = "/ecs/${var.project_name}/service1"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "service2" {
  name              = "/ecs/${var.project_name}/service2"
  retention_in_days = 7

  tags = var.tags
}

# Task Definition for Microservice 1 (REST API)
resource "aws_ecs_task_definition" "service1" {
  family                   = "${var.project_name}-service1"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "service1"
      image     = var.service1_image
      cpu       = 256
      memory    = 256
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0  # Dynamic port mapping
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "SSM_PARAMETER_NAME"
          value = var.ssm_parameter_name
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service1.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# Task Definition for Microservice 2 (SQS Worker)
resource "aws_ecs_task_definition" "service2" {
  family                   = "${var.project_name}-service2"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "service2"
      image     = var.service2_image
      cpu       = 256
      memory    = 256
      essential = true

      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "S3_BUCKET_NAME"
          value = var.s3_bucket_name
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service2.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# ECS Service for Microservice 1
resource "aws_ecs_service" "service1" {
  name            = "${var.project_name}-service1"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service1.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service1.arn
    container_name   = "service1"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main
  ]

  tags = var.tags
}

# ECS Service for Microservice 2
resource "aws_ecs_service" "service2" {
  name            = "${var.project_name}-service2"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service2.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 0
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.main
  ]

  tags = var.tags
}
