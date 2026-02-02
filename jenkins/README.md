# Jenkins Local Setup (IaC)

Jenkins running locally via Docker Compose with Configuration as Code (JCasC).

## Quick Start

```bash
cd jenkins
cp .env.example .env
# Edit .env with your AWS credentials
docker-compose up -d
```

Open http://localhost:8080

**Login:** admin / admin

## Install Required Plugins

After first start, install plugins from **Manage Jenkins → Plugins → Available**:
- Pipeline
- Docker Pipeline
- Git
- Credentials Binding
- Pipeline: AWS Steps
- Configuration as Code
- Job DSL

Then restart Jenkins: `docker-compose restart`

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Docker Compose config |
| `casc.yaml` | Jenkins Configuration as Code |
| `plugins.txt` | Required plugins list |
| `.env.example` | Environment template |

## Jobs

| Job | Description |
|-----|-------------|
| `checkpoint-exam-ci` | Build & push Docker images to ECR |
| `checkpoint-exam-cd` | Deploy to ECS (parametrized) |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `AWS_REGION` | AWS region (default: us-east-1) |

## Commands

```bash
docker-compose up -d      # Start
docker-compose logs -f    # View logs
docker-compose down       # Stop
docker-compose down -v    # Stop and remove data
docker-compose restart    # Restart
```
