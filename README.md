# dev-self-service-platform

A self-service Internal Developer Platform (IDP) that lets developers provision isolated Kubernetes environments on demand via a web form. Each request triggers a fully automated workflow that provisions an EKS namespace, configures Kubernetes policies, creates an Azure Entra ID group, provisions a Grafana dashboard, and notifies the requester.

---

## Architecture

```
Developer → Web UI (S3 / CloudFront)
              │
              ▼
         API Gateway (POST /environments)
              │
              ▼
         Lambda Orchestrator
              │  writes initial record to DynamoDB
              ▼
         Step Functions Workflow
              ├── CodeBuild: Terraform → EKS namespace + RBAC
              ├── CodeBuild: Ansible  → ResourceQuota, LimitRange, NetworkPolicy
              ├── Lambda:   Entra ID  → create AAD group, assign owner
              ├── Lambda:   Grafana   → provision per-namespace dashboard
              └── Lambda:   Notify    → SES email with kubeconfig + links
```

### Infrastructure Components

| Component | Technology |
|---|---|
| Web UI | S3 + CloudFront |
| API | API Gateway + Lambda (Python) |
| Workflow | AWS Step Functions |
| K8s provisioning | CodeBuild + Terraform |
| K8s configuration | CodeBuild + Ansible |
| Identity | Azure Entra ID (Microsoft Graph API) |
| Observability | Grafana (API-provisioned dashboard) |
| State | DynamoDB |
| Secrets | AWS Secrets Manager |
| Networking | VPC, private subnets, NAT Gateway |
| Compute | EKS managed node group |

---

## Repository Structure

```
dev-self-service-platform/
├── terraform/
│   ├── bootstrap/          # S3 backend + DynamoDB lock table
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── eks-namespace/  # called per-request by CodeBuild
│   │   ├── codebuild/
│   │   ├── api-gateway/
│   │   ├── lambda/
│   │   ├── step-functions/
│   │   └── s3-cloudfront/
│   └── environments/
│       └── prod/
├── lambda/
│   ├── orchestrator/
│   ├── entra/
│   ├── grafana/
│   ├── update-status/
│   └── notify/
├── step-functions/
│   └── workflow.asl.json
├── ansible/
│   ├── playbooks/
│   └── roles/namespace-config/
├── web-ui/
│   ├── index.html
│   ├── app.js
│   └── styles.css
├── buildspec/
│   ├── terraform-namespace.yml
│   └── ansible-namespace.yml
└── Makefile
```

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- Ansible >= 2.14 with `kubernetes.core` collection
- GitHub CLI (`gh`)
- Python 3.12
- An EKS cluster (provisioned by `feature/infra-core`)
- Azure App Registration with `Group.ReadWrite.All` permission
- Grafana instance with an API key

---

## Quick Start

### 1. Bootstrap Terraform backend

```bash
make bootstrap
```

### 2. Set required secrets in AWS Secrets Manager

```bash
# Azure Entra ID credentials
aws secretsmanager create-secret \
  --name idp/entra-credentials \
  --secret-string '{"tenant_id":"<>","client_id":"<>","client_secret":"<>"}'

# Grafana credentials
aws secretsmanager create-secret \
  --name idp/grafana-credentials \
  --secret-string '{"url":"https://grafana.example.com","api_key":"<>"}'
```

### 3. Deploy core infrastructure

```bash
make deploy-infra
```

### 4. Build and deploy Lambda functions

```bash
make build-lambdas
make deploy-lambdas
```

### 5. Deploy web UI

```bash
make deploy-ui
```

---

## Requesting an Environment

Open the CloudFront URL and fill in:

- **Team** — e.g. `payments`
- **Project** — e.g. `checkout-api`
- **Owner email** — provisioning notifications sent here
- **CPU limit** — 0.5 / 1 / 2 / 4 cores
- **Memory limit** — 512Mi / 1Gi / 2Gi / 4Gi

Provisioning takes ~5–8 minutes. You will receive an email with:
- Namespace name
- kubeconfig snippet
- Grafana dashboard URL
- Azure Entra ID group name

---

## What Gets Provisioned Per Environment

| Resource | Details |
|---|---|
| K8s Namespace | `<team>-<project>-<env_id>` |
| ResourceQuota | CPU + memory limits as requested |
| LimitRange | Default container limits |
| NetworkPolicy | Deny-all ingress; allow same-namespace + monitoring |
| ServiceAccount | `<env_id>-sa` with scoped RBAC |
| Entra ID Group | `idp-<team>-<project>-<env_id>` |
| Grafana Dashboard | Per-namespace pod/CPU/memory panels |

---

## Local Development

```bash
# Validate Terraform modules
make tf-validate

# Lint Ansible roles
make ansible-lint

# Run Lambda unit tests
make test-lambdas
```

---

## Secrets Required

| Secret Name | Keys |
|---|---|
| `idp/entra-credentials` | `tenant_id`, `client_id`, `client_secret` |
| `idp/grafana-credentials` | `url`, `api_key` |
| `idp/ses-config` | `from_email` |
