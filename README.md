# Trendify – Full AWS Deployment Guide

**App:** Trendify (React/Vite e-commerce app)
**Stack:** Docker → DockerHub → Jenkins CI/CD → AWS EKS (Kubernetes)
**Infrastructure:** Terraform (VPC, EC2/Jenkins, EKS)
**Monitoring:** Prometheus + Grafana

---

## 📁 Project Structure

```
Trend-source/
├── dist/                    # Pre-built React app (served by nginx)
├── Dockerfile               # Containerizes the app with nginx
├── nginx.conf               # nginx config – SPA routing on port 3000
├── Jenkinsfile              # Declarative CI/CD pipeline
├── .gitignore
├── .dockerignore
├── k8s/
│   └── deployment.yaml      # Kubernetes Deployment + LoadBalancer Service
├── terraform/
│   └── main.tf              # VPC, EC2 Jenkins, EKS cluster
└── README.md
```

---

## PHASE 1 – Local Setup & Run on Port 3000

### Prerequisites
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Install [Git](https://git-scm.com/downloads)
- Install [Node.js 18+](https://nodejs.org/) (optional, only if you want to rebuild)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/Vennilavanguvi/Trend.git
cd Trend

# 2. Build Docker image
docker build -t trendify:local .

# 3. Run the container (mapped to port 3000)
docker run -d -p 3000:3000 --name trendify-app trendify:local

# 4. Open browser: http://localhost:3000
```

**Expected output:** Trendify e-commerce app running at `http://localhost:3000`

---

## PHASE 2 – DockerHub Repository

### Steps

```bash
# 1. Login to DockerHub (create account at hub.docker.com if needed)
docker login

# 2. Tag your image
docker tag trendify:local dinesh0793/trendify:latest

# 3. Push to DockerHub
docker push dinesh0793/trendify:latest
```

✅ Visit `https://hub.docker.com/r/dinesh0793/trendify` to confirm.

---

## PHASE 3 – Push Code to GitHub

```bash
# 1. Create a new GitHub repo (e.g., trendify-deploy) at github.com

# 2. Inside the project folder
cd Trend-source
git init
git remote add origin https://github.com/Dinesh0793/Trend-proj-2.git

# 3. Stage and commit all files
git add .
git commit -m "Initial commit: Trendify with Docker, K8s, Terraform, Jenkinsfile"

# 4. Push to GitHub
git branch -M main
git push -u origin main
```

---

## PHASE 4 – Terraform: Provision AWS Infrastructure

### Prerequisites
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) installed (v1.0+)
- An existing EC2 Key Pair in your AWS account

### Edit terraform/main.tf
Change these two variables at the top:
```hcl
variable "key_pair_name" {
  default = "your-actual-key-pair-name"   # ← YOUR KEY PAIR
}
```

### Terraform Commands

```bash
# Go to terraform folder
cd terraform

# Initialize Terraform (downloads AWS provider)
terraform init

# Preview what will be created
terraform plan

# Create all resources (type 'yes' when prompted)
terraform apply

# After completion, note down:
# - jenkins_public_ip    → your Jenkins server IP
# - jenkins_url          → http://<IP>:8080
# - eks_cluster_name     → trendify-cluster
```

**Resources created:**
| Resource | Details |
|---|---|
| VPC | 10.0.0.0/16 |
| Public Subnets | 2 subnets in ap-south-1a, ap-south-1b |
| Internet Gateway | For public internet access |
| Security Groups | SSH (22), Jenkins (8080) |
| IAM Roles | Jenkins EC2 role, EKS cluster role, EKS node role |
| EC2 Instance | t3.medium – Jenkins + Docker + kubectl auto-installed |
| EKS Cluster | trendify-cluster (Kubernetes 1.29) |
| EKS Node Group | 2x t3.medium worker nodes |

> ⏱️ EKS cluster takes **10-15 minutes** to fully provision.

---

## PHASE 5 – Configure Jenkins

### Access Jenkins

```
http://<jenkins_public_ip>:8080
```

### Initial Setup

```bash
# SSH into the Jenkins EC2
ssh -i your-key.pem ec2-user@<jenkins_public_ip>

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Install Required Plugins
Go to **Manage Jenkins → Plugins → Available plugins** and install:
- ✅ Docker Pipeline
- ✅ Docker Commons Plugin
- ✅ Git plugin (usually pre-installed)
- ✅ Pipeline
- ✅ Kubernetes CLI Plugin
- ✅ AWS Steps Plugin
- ✅ GitHub plugin
- ✅ Blue Ocean (optional, better UI)

### Add DockerHub Credentials
1. Go to **Manage Jenkins → Credentials → System → Global credentials**
2. Click **Add Credentials**
3. Select **Username with password**
4. ID: `dockerhub-credentials`
5. Username: `dinesh0793`
6. Password: `YOUR_DOCKERHUB_PASSWORD`

### Configure kubectl on Jenkins
```bash
# SSH into Jenkins EC2
ssh -i your-key.pem ec2-user@<jenkins_public_ip>

# Configure kubectl to connect to your EKS cluster
aws eks update-kubeconfig --region ap-south-1 --name trendify-cluster

# Test connection
kubectl get nodes
```

---

## PHASE 6 – GitHub Webhook for Auto-Trigger

### Jenkins Job → GitHub Webhook

1. In Jenkins, create a new **Pipeline** project
2. Under **Build Triggers**, check: ✅ **GitHub hook trigger for GITScm polling**
3. Under **Pipeline**, select **Pipeline script from SCM**
   - SCM: Git
   - Repository URL: `https://github.com/Dinesh0793/Trend-proj-2.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

### GitHub Side
1. Go to your GitHub repo → **Settings → Webhooks → Add webhook**
2. Payload URL: `http://<jenkins_public_ip>:8080/github-webhook/`
3. Content type: `application/json`
4. Events: ✅ **Just the push event**
5. Click **Add webhook**

**Result:** Every `git push` to `main` automatically triggers the Jenkins pipeline.

---

## PHASE 7 – Create & Run Jenkins Pipeline

### Jenkinsfile Walkthrough
The included `Jenkinsfile` has these stages:

```
Checkout → Build Docker Image → Push to DockerHub → 
Update K8s Manifest → Configure kubectl → Deploy to EKS → Verify
```

### Before Running – Jenkinsfile is Ready ✅
`DOCKERHUB_USERNAME` is already set to `dinesh0793` in the `Jenkinsfile`.

### Run the Pipeline
1. Push your code to GitHub (triggers webhook)
2. Or manually click **Build Now** in Jenkins
3. Watch stages execute in Blue Ocean or classic view

---

## PHASE 8 – Verify EKS Deployment

```bash
# On Jenkins EC2 (or any machine with kubectl configured)

# Check nodes are running
kubectl get nodes

# Check pods
kubectl get pods -l app=trendify

# Check service and get LoadBalancer URL
kubectl get service trendify-service

# Example output:
# NAME               TYPE           CLUSTER-IP     EXTERNAL-IP                          PORT(S)
# trendify-service   LoadBalancer   10.100.x.x     xxx.ap-south-1.elb.amazonaws.com      80:30xxx/TCP
```

Copy the **EXTERNAL-IP** — that is your **Load Balancer ARN / DNS** to include in your submission.

**Access the app:** `http://<EXTERNAL-IP>`

---

## PHASE 9 – Monitoring (Prometheus + Grafana)

### Install Prometheus & Grafana on EKS using Helm

```bash
# Install Helm (on Jenkins EC2)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Prometheus community charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Grafana)
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# Check pods are running
kubectl get pods -n monitoring
```

### Access Grafana Dashboard

```bash
# Port-forward to access Grafana locally
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80

# Open: http://localhost:3001
# Default login: admin / prom-operator
```

**Grafana provides:** Cluster health, pod CPU/memory usage, node status, HTTP traffic dashboards.

---

## PHASE 10 – Cleanup (To avoid AWS charges)

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/deployment.yaml

# Destroy all Terraform-managed AWS resources
cd terraform
terraform destroy
```

---

## 📋 Submission Checklist

| Item | Details |
|---|---|
| GitHub Repo | Push full code with all config files |
| DockerHub | `dinesh0793/trendify` image pushed |
| Terraform | VPC, EC2, EKS provisioned |
| Jenkins | Pipeline created, webhook configured |
| EKS | App deployed and running |
| LoadBalancer ARN | `kubectl get svc trendify-service` (EXTERNAL-IP) |
| README | This file |
| Screenshots | Jenkins build, DockerHub, EKS pods, app in browser |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---|---|
| Jenkins unreachable | Check EC2 Security Group port 8080 is open |
| `kubectl` no cluster | Run `aws eks update-kubeconfig ...` on Jenkins EC2 |
| Pod CrashLoopBackOff | `kubectl logs <pod-name>` to see error |
| Docker push denied | Check `dockerhub-credentials` ID in Jenkinsfile matches Jenkins |
| EKS timeout | EKS takes 10-15 min to provision, wait and retry |
| LoadBalancer pending | EKS LoadBalancer takes 2-3 min to get external IP |
