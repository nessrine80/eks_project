# 🚀 LLM-on-AWS Project

This project deploys a backend application using GitHub Actions CI/CD pipelines, Docker, Kubernetes, and Terraform on AWS. The pipelines handle building, pushing, deploying, and destroying infrastructure and application resources automatically.

---

## ⚙️ Initial Terraform Backend Setup

Before doing anything else in this project, you must first create your Terraform S3 backend and DynamoDB lock table using the script below.

```bash
#!/bin/bash

# ======= CONFIGURATION ========
REGION="us-east-1"
BUCKET_NAME="ttf-remote-backend-state-4286"
DYNAMO_TABLE="terraform-locks"
STATE_KEY="dev/terraform.tfstate"
# ==============================

echo "🔧 Creating S3 bucket: $BUCKET_NAME"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

echo "⏳ Waiting for bucket to exist..."
until aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; do
  sleep 2
done

echo "🔐 Enabling encryption on bucket"
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "📦 Enabling versioning on bucket"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "🗄️ Creating DynamoDB table: $DYNAMO_TABLE"
aws dynamodb create-table \
  --table-name "$DYNAMO_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null

echo "✅ Done! Terraform backend infrastructure is ready."
```

---

## 📁 Project Structure

```text
project/
├── .github/workflows/          # GitHub Actions pipelines
│   ├── build_push.yml          # Builds & pushes Docker image
│   ├── k8s_deploy.yml          # Deploys app to Kubernetes
│   ├── terraform_deployment.yml# Provisions AWS infrastructure
│   └── terraform_destroy.yml   # Destroys AWS infrastructure
├── app/
│   ├── backend/                # Python Flask backend
│   │   ├── app.py              # Main application
│   │   └── config.py           # App config
│   └── Dockerfile              # Containerize app
├── infra/                      # Terraform code
│   ├── main.tf                 # Terraform resources
│   └── variables.tf            # Terraform variables
```

---

## 🔐 GitHub Secrets Used

| Secret Name               | Description                                 |
|--------------------------|---------------------------------------------|
| `AWS_ACCESS_KEY_ID`      | AWS access key to deploy infrastructure     |
| `AWS_SECRET_ACCESS_KEY`  | AWS secret access key                       |
| `AWS_REGION`             | AWS region (e.g. `us-east-1`)               |
| `ECR_REPOSITORY`         | Name of the ECR repository                  |
| `KUBE_CONFIG_DATA`       | Base64 encoded Kubeconfig for cluster auth  |

---

## ⚙️ CI/CD Pipelines Overview

- `build_push.yml`: Builds Docker image and pushes to ECR
- `terraform_deployment.yml`: Provisions AWS infra via Terraform
- `terraform_destroy.yml`: Destroys AWS infra
- `k8s_deploy.yml`: Deploys the app to Kubernetes

---

## 💻 Running Locally

### Prerequisites:
- Docker
- Python 3
- AWS CLI (configured)
- Terraform
- kubectl

### Run the App Locally

```bash
cd app
docker build -t llm:v1 .
docker run -p 8080:8080 llm:v1
```

### Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply -auto-approve
```

### Deploy to Kubernetes

```bash
kubectl apply -f k8s/
```

---

## 🚀 GitHub Actions Triggers

Use these commit messages when pushing to `main`:

- `terraform apply`
- `terraform destroy`
- `k8s deploy`

---

## 🧼 Tear Down Infrastructure

```bash
cd infra
terraform destroy -auto-approve
```

---

## 📊 Monitoring with Prometheus & Grafana

### Prerequisites

- EKS cluster configured with `kubectl`
- Helm installed

### 1. Add Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 2. Install Prometheus Stack

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### 3. Install Grafana

```bash
helm install grafana grafana/grafana \
  --namespace monitoring
```

### 4. Patch Grafana Service (LoadBalancer)

```bash
kubectl patch svc prometheus-grafana \
  -n monitoring \
  --type merge \
  -p '{
    "spec": {
      "type": "LoadBalancer",
      "ports": [
        {
          "name": "http",
          "protocol": "TCP",
          "port": 80,
          "targetPort": 3000
        }
      ]
    }
  }'
```

### 5. Get Grafana Password

```bash
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

### 6. Test Prometheus Access

```bash
kubectl exec -n monitoring -it $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}") -- curl -s http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

### 7. Add Prometheus as a Grafana Data Source

Use this URL:

```
http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

---

### 8. Import Grafana Dashboards

- Go to **Create → Import**
- Use IDs from https://grafana.com/grafana/dashboards/

---

## 📈 Kubernetes Metrics Server

Install Metrics Server to enable resource metrics:

```bash
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
```

> Version: `v0.7.1`