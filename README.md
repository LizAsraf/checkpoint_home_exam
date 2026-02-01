# Checkpoint DevOps Home Exam

A microservices system built on AWS ECS with SQS message queue and S3 storage, fully deployed via Terraform (IaC).

## Architecture Overview

```
                                    ┌─────────────────┐
                                    │  SSM Parameter  │
                                    │  (API Token)    │
                                    └────────┬────────┘
                                             │ read token
                                             ▼
┌──────┐    ┌─────┐    ┌──────────────────────────────┐    ┌─────┐    ┌──────────────────────────────┐    ┌─────┐
│ User │───▶│ ALB │───▶│      Microservice 1          │───▶│ SQS │───▶│      Microservice 2          │───▶│ S3  │
└──────┘    └─────┘    │  (validate token, send msg)  │    └─────┘    │  (poll queue, upload to S3)  │    └─────┘
                       └──────────────────────────────┘               └──────────────────────────────┘
                                    │
                                    │ runs on
                                    ▼
                            ┌───────────────┐
                            │  ECS Cluster  │
                            │  (t2.micro)   │
                            └───────────────┘
```

## Components

| Component | Description | Free Tier? |
|-----------|-------------|------------|
| **ECS Cluster** | Container orchestration (control plane is FREE) | YES |
| **EC2 t2.micro** | ECS instance (750 hrs/month free) | YES |
| **ECR** | Docker image registry | YES (500MB) |
| **ALB** | Application Load Balancer | NO (~$16/mo) |
| **SQS** | Message queue (1M requests/month free) | YES |
| **S3** | Storage bucket (5GB free) | YES |
| **SSM Parameter** | Stores API token securely | YES |
| **CloudWatch** | Monitoring dashboard & alarms | YES (basic) |

## Project Structure

```
checkpoint_home_exam/
├── README.md
├── Terraform/                    # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   ├── terraform.tfvars
│   └── modules/
│       ├── ecs/                  # ECS cluster, services, ALB
│       ├── ecr/                  # Docker image repositories
│       ├── networking/           # VPC, subnets
│       ├── security/             # IAM roles, security groups
│       ├── sqs/                  # SQS queue
│       ├── s3/                   # S3 bucket
│       ├── ssm/                  # SSM Parameter (API token)
│       └── monitoring/           # CloudWatch dashboard & alarms
├── microservices/
│   ├── service1/                 # REST API
│   │   ├── app.py               # Flask application
│   │   ├── test_app.py          # Unit tests
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── service2/                 # SQS Worker
│       ├── app.py               # Worker application
│       ├── test_app.py          # Unit tests
│       ├── Dockerfile
│       └── requirements.txt
└── ci-cd/
    ├── Jenkinsfile.ci            # CI: Build & push images
    ├── Jenkinsfile.cd            # CD: Deploy to ECS
    └── README.md                 # Jenkins setup guide
```

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed
- Terraform >= 1.0 installed
- Docker installed
- Python 3.11+ (for local testing)

---

## Quick Start Guide

### Step 1: Clone the Repository

```bash
git clone https://github.com/LizAsraf/checkpoint_home_exam.git
cd checkpoint_home_exam
```

### Step 2: Configure AWS Credentials

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### Step 3: Deploy Infrastructure

```bash
cd Terraform
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. This creates all AWS resources (~5-10 minutes).

### Step 4: Get Outputs

```bash
# Get the ALB URL
terraform output alb_dns_name

# Get the generated API token
terraform output -raw api_token

# Get ECR repository URLs
terraform output ecr_service1_url
terraform output ecr_service2_url

# Get CloudWatch dashboard URL
terraform output cloudwatch_dashboard_url
```

### Step 5: Build and Push Docker Images

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_service1_url | cut -d'/' -f1)

# Build and push Service 1
cd ../microservices/service1
docker build -t $(terraform output -raw ecr_service1_url):latest .
docker push $(terraform output -raw ecr_service1_url):latest

# Build and push Service 2
cd ../service2
docker build -t $(terraform output -raw ecr_service2_url):latest .
docker push $(terraform output -raw ecr_service2_url):latest
```

### Step 6: Update ECS with Real Images

```bash
cd ../../Terraform

# Update terraform.tfvars with ECR URLs
# service1_image = "<ecr_url>/checkpoint-exam/service1:latest"
# service2_image = "<ecr_url>/checkpoint-exam/service2:latest"

terraform apply
```

### Step 7: Test the API

```bash
# Get the ALB DNS and API token
ALB_DNS=$(terraform output -raw alb_dns_name)
API_TOKEN=$(terraform output -raw api_token)

# Send a test request
curl -X POST http://${ALB_DNS}/api/message \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Happy new year!",
      "email_sender": "John doe",
      "email_timestream": "1693561101",
      "email_content": "Just want to say... Happy new year!!!"
    },
    "token": "'"${API_TOKEN}"'"
  }'
```

Expected response:
```json
{
  "status": "success",
  "message": "Message sent to queue",
  "message_id": "xxx-xxx-xxx"
}
```

### Step 8: Verify Message in S3

```bash
# List objects in S3 bucket
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/messages/ --recursive
```

---

## Running Tests Locally

### Service 1 Tests

```bash
cd microservices/service1
pip install -r requirements.txt
pytest test_app.py -v
```

### Service 2 Tests

```bash
cd microservices/service2
pip install -r requirements.txt
pytest test_app.py -v
```

---

## CI/CD Pipeline

### Jenkins Setup

See `ci-cd/README.md` for detailed Jenkins configuration.

### CI Pipeline (Jenkinsfile.ci)
- Runs unit tests for both services
- Builds Docker images
- Pushes to ECR with version tags

### CD Pipeline (Jenkinsfile.cd)
- Takes image version as parameter
- Updates ECS task definitions
- Deploys to ECS cluster
- Waits for stable deployment

---

## Monitoring

### CloudWatch Dashboard

Access the dashboard after deployment:

```bash
terraform output cloudwatch_dashboard_url
```

The dashboard displays:
- ECS CPU/Memory utilization
- ALB request count and response time
- SQS queue depth and message age
- S3 bucket size

### CloudWatch Alarms

| Alarm | Trigger |
|-------|---------|
| ECS High CPU | CPU > 80% for 10 min |
| ECS High Memory | Memory > 80% for 10 min |
| ALB 5XX Errors | > 10 errors in 5 min |
| SQS Queue Depth | > 100 messages |
| SQS Message Age | Messages > 1 hour old |
| ALB Unhealthy Hosts | Any unhealthy targets |

---

## API Specification

### Endpoint: POST /api/message

**Request:**
```json
{
  "data": {
    "email_subject": "Happy new year!",
    "email_sender": "John doe",
    "email_timestream": "1693561101",
    "email_content": "Just want to say... Happy new year!!!"
  },
  "token": "<api_token_from_ssm>"
}
```

**Validation:**
- Token must match the value stored in SSM Parameter Store
- All 4 fields (email_subject, email_sender, email_timestream, email_content) are required
- All fields must be non-empty strings

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Message sent to queue",
  "message_id": "xxx-xxx-xxx"
}
```

**Error Responses:**
- 400: Invalid payload or missing fields
- 401: Invalid or missing token
- 500: Internal server error

---

## Cleanup

To destroy all resources and avoid charges:

```bash
cd Terraform
terraform destroy
```

Type `yes` when prompted.

---

## Cost Estimation

| Resource | Monthly Cost |
|----------|--------------|
| ECS Cluster | FREE |
| EC2 t2.micro (750 hrs) | FREE |
| ECR (500MB) | FREE |
| SQS (1M requests) | FREE |
| S3 (5GB) | FREE |
| SSM Parameter | FREE |
| CloudWatch (basic) | FREE |
| **ALB** | **~$16** |
| **NAT Gateway (2x)** | **~$65** |
| **Total** | **~$81/month** |

> Note: The main costs are ALB and NAT Gateways. For true free tier, networking could be modified to use public subnets only.

---

## Exam Requirements Checklist

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Create Jenkins CI/CD tool | ✅ Done |
| 2 | Build cloud environment with IaC (Terraform) | ✅ Done |
| 3 | Create SQS and S3 bucket | ✅ Done |
| 4 | Microservice 1 - REST API with token validation | ✅ Done |
| 5 | Microservice 2 - SQS worker, upload to S3 | ✅ Done |
| 6 | CI jobs - Build Docker, push to registry | ✅ Done |
| 7 | CD jobs - Deploy to ECS | ✅ Done |
| **Bonus 1** | Create tests for the process | ✅ Done |
| **Bonus 2** | Add monitoring (CloudWatch) | ✅ Done |
