# 🚀 LLM-on-AWS Project

This project deploys a backend application using GitHub Actions CI/CD pipelines, Docker, Kubernetes, and Terraform on AWS. The pipelines handle building, pushing, deploying, and destroying infrastructure and application resources automatically.

---

## 📁 Project Structure

```
project/
│
├── .github/workflows/          # GitHub Actions pipelines
│   ├── build_push.yml          # Builds & pushes Docker image
│   ├── k8s_deploy.yml          # Deploys app to Kubernetes
│   ├── terraform_deployment.yml# Provisions AWS infrastructure
│   └── terraform_destroy.yml   # Destroys AWS infrastructure
│
├── app/
│   ├── backend/                # Python Flask backend
│   │   ├── app.py              # Main application
│   │   └── config.py           # App config
│   └── Dockerfile              # Containerize app
│
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

### ✅ 1. `build_push.yml`
- Triggered on: Push to `main` branch.
- Action: Builds Docker image, logs into AWS ECR, and pushes the image.

### ✅ 2. `terraform_deployment.yml`
- Triggered when commit message starts with `terraform apply`
- Action: Initializes Terraform and applies AWS infrastructure.

### ✅ 3. `terraform_destroy.yml`
- Triggered when commit message starts with `terraform destroy`
- Action: Runs `terraform destroy` to clean up resources.

### ✅ 4. `k8s_deploy.yml`
- Triggered when commit message starts with `k8s deploy`
- Action: Applies Kubernetes manifests and deploys backend service.

---

## 💻 Running Locally

### Prerequisites:
- Docker
- Python 3
- AWS CLI (with configured credentials)
- Terraform
- kubectl

### 1. Build & Run Locally
```bash
cd app
docker build -t llm:v1 .
docker run -p 8080:8080 llm:v1
```

### 2. Deploy with Terraform
```bash
cd infra
terraform init
terraform apply -auto-approve
```

### 3. Deploy to Kubernetes
```bash
kubectl apply -f k8s/
```

---

## 🚀 GitHub Actions Usage

To trigger specific pipelines, use **commit messages**:

- `terraform apply`: Triggers infrastructure creation
- `terraform destroy`: Triggers infrastructure destruction
- `k8s deploy`: Triggers Kubernetes deployment

> 💡 These pipelines run only when pushed to the `main` branch.

---

## 🧼 Destroy Resources
```bash
cd infra
terraform destroy -auto-approve
```

---

## 📊 Monitoring with Prometheus & Grafana

### Prerequisites

Before starting, ensure you have:

- A running EKS cluster with `kubectl` configured to interact with it.
- Helm installed on your local machine.

If you don’t have Helm installed, you can install it with:

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

---

### Step 1: Add Prometheus and Grafana Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

### Step 2: Install Prometheus in Your EKS Cluster

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

---

### Step 3: Install Grafana in Your EKS Cluster

```bash
helm install grafana grafana/grafana \
  --namespace monitoring
```

---

### Step 4: Patch Grafana Service for LoadBalancer Access

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

---

### Step 5: Retrieve Grafana Admin Password

```bash
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

---

### Step 6: Test Prometheus Connectivity from Grafana Pod

```bash
kubectl exec -n monitoring -it $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}") -- curl -s http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

---

### Step 7: Add Prometheus as a Data Source in Grafana

1. Go to **Grafana → Configuration → Data Sources → Add Data Source**.
2. Choose **Prometheus**.
3. Set the URL to:

```
http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

4. Click **Save & Test**.

---

### Step 8: Import Grafana Dashboards

- Go to **Create → Import**
- Use dashboard IDs from https://grafana.com/grafana/dashboards/
- Example: Kubernetes, EKS, or Node Exporter dashboards
---

## 📈 Kubernetes Metrics Server

To install the Metrics Server (for `kubectl top nodes` and `kubectl top pods` to work):

```bash
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
```

> 📌 This command deploys Metrics Server version `v0.7.1` to your cluster.