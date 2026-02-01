# CI/CD Pipelines

This folder contains Jenkins pipeline definitions for Continuous Integration and Continuous Deployment.

## Pipelines

### CI Pipeline (`Jenkinsfile.ci`)

Builds and pushes Docker images to ECR.

**Stages:**
1. Checkout code
2. Login to ECR
3. Build Service 1 Docker image
4. Build Service 2 Docker image
5. Push Service 1 to ECR
6. Push Service 2 to ECR
7. Cleanup

**Triggers:** On every push to main branch

**Image Tags Created:**
- `{build-number}` - Jenkins build number
- `{git-commit}` - Short git commit hash
- `latest` - Always points to newest build

### CD Pipeline (`Jenkinsfile.cd`)

Deploys images to ECS.

**Parameters:**
- `IMAGE_TAG` - Which version to deploy (default: latest)
- `SERVICE` - Which service to deploy (both, service1, or service2)

**Stages:**
1. Validate parameters
2. Verify images exist in ECR
3. Deploy Service 1 (update task definition, update service)
4. Deploy Service 2 (update task definition, update service)
5. Wait for deployment to stabilize

## Jenkins Setup

### Required Credentials

Configure these in Jenkins → Manage Jenkins → Credentials:

1. **aws-credentials** (AWS Credentials)
   - Access Key ID
   - Secret Access Key

2. **aws-account-id** (Secret Text)
   - Your AWS Account ID

### Required Plugins

- AWS Steps Plugin
- Pipeline AWS Steps
- Docker Pipeline

### Create Jobs

1. **CI Job:**
   - New Item → Pipeline
   - Name: `checkpoint-exam-ci`
   - Pipeline from SCM → Git → Your repo URL
   - Script Path: `ci-cd/Jenkinsfile.ci`

2. **CD Job:**
   - New Item → Pipeline
   - Name: `checkpoint-exam-cd`
   - Pipeline from SCM → Git → Your repo URL
   - Script Path: `ci-cd/Jenkinsfile.cd`
   - Check "This project is parameterized"

## Usage

### Build New Images (CI)

```bash
# Trigger from Jenkins UI or:
curl -X POST http://jenkins-url/job/checkpoint-exam-ci/build
```

### Deploy to ECS (CD)

```bash
# Deploy latest to both services
curl -X POST "http://jenkins-url/job/checkpoint-exam-cd/buildWithParameters?IMAGE_TAG=latest&SERVICE=both"

# Deploy specific version to service1 only
curl -X POST "http://jenkins-url/job/checkpoint-exam-cd/buildWithParameters?IMAGE_TAG=42&SERVICE=service1"
```

## Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Git Push  │────▶│  CI Pipeline │────▶│    ECR      │
│             │     │  (Build)     │     │  (Images)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    ECS      │◀────│  CD Pipeline │◀────│   Trigger   │
│  (Running)  │     │  (Deploy)    │     │  (Manual)   │
└─────────────┘     └─────────────┘     └─────────────┘
```
