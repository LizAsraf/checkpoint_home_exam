# Main Terraform configuration - orchestrates all modules
# Dependency order: networking → security → ecs, sqs, s3, ssm

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "networking" {
  source = "./modules/networking"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  project_name       = var.project_name
  environment        = var.environment
  tags               = var.tags
}

module "security" {
  source = "./modules/security"

  vpc_id       = module.networking.vpc_id
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
  tags         = var.tags
}

module "ssm" {
  source = "./modules/ssm"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  public_subnet_ids           = module.networking.public_subnet_ids
  ecs_security_group_id       = module.security.ecs_security_group_id
  alb_security_group_id       = module.security.alb_security_group_id
  ecs_instance_profile_arn    = module.security.ecs_instance_profile_arn
  ecs_task_execution_role_arn = module.security.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.security.ecs_task_role_arn
  instance_type               = var.ecs_instance_type
  desired_capacity            = var.ecs_desired_capacity
  min_size                    = var.ecs_min_size
  max_size                    = var.ecs_max_size
  service1_image              = var.service1_image
  service2_image              = var.service2_image
  sqs_queue_url               = module.sqs.queue_url
  s3_bucket_name              = module.s3.bucket_name
  ssm_parameter_name          = module.ssm.parameter_name
  aws_region                  = var.aws_region
  tags                        = var.tags

  depends_on = [module.sqs, module.s3, module.ssm]
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  ecs_cluster_name        = module.ecs.cluster_name
  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
  sqs_queue_name          = module.sqs.queue_name
  s3_bucket_name          = module.s3.bucket_name
  tags                    = var.tags

  depends_on = [module.ecs]
}
