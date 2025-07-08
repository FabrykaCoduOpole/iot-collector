# IoT Data Collector System

# Overview
This project implements a scalable, secure microservice-based IoT Data Collector System that integrates with AWS cloud services. The system collects data from IoT devices via MQTT protocol, stores it in a database, and provides monitoring and observability capabilities.

# Architecture diagrams
![AWS IoT Collector Architecture](./docs/arch.jpg)

### Overview
This diagram illustrates the **AWS network architecture** of the `iot-collector-dev` environment deployed in the `us-east-1` region. The infrastructure is built to collect, process, and store IoT data using AWS IoT Core, Amazon EKS, and Amazon RDS PostgreSQL.

---
### VPC Layout
- **VPC CIDR:** `10.0.0.0/16`
- **Region:** `us-east-1`
- **Availability Zones:**
  - `us-east-1a`
  - `us-east-1b`
---

### Subnets & NAT
| Subnet Name                  | CIDR Block     | AZ         | Purpose                        |
|-----------------------------|----------------|------------|--------------------------------|
| `iot-collector-dev-public-1`  | `10.0.0.0/24`   | us-east-1a | NAT Gateway                    |
| `iot-collector-dev-public-2`  | `10.0.1.0/24`   | us-east-1b | Reserved for HA NAT            |
| `iot-collector-dev-private-1` | `10.0.10.0/24`  | us-east-1a | EKS cluster and services       |
| `iot-collector-dev-private-2` | `10.0.11.0/24`  | us-east-1b | EKS node group                 |
| `iot-collector-dev-database-1`| `10.0.20.0/24`  | us-east-1a | RDS PostgreSQL                 |
| `iot-collector-dev-database-2`| `10.0.21.0/24`  | us-east-1b | RDS PostgreSQL                 |
- **NAT Gateway:** Deployed in `public-1` (AZ `us-east-1a`)
- **Elastic IP:** `35.170.228.176`

---

### AWS IoT Core
- Receives messages from IoT devices
- Subscribed topic:  
  sdk/test/python
### Amazon EKS
- Deployed in private subnets `10.0.10.0/24`, `10.0.11.0/24` (AZ `us-east-1a`, `us-east-1b`) with no public IPs
- Manages containerized services:
#### `Api-Gateway` with endpoints for health checks, device management, and data retrieval
- `GET /health` – Health check endpoint to verify that the API Gateway service is running properly.  
- `GET /api/devices` – Retrieves a list of all devices that have sent data to the system.  
- `GET /api/devices/{deviceId}/data` – Retrieves time-series data for a specific device with optional query parameters (`limit`, `from`, `to`).  
- `GET /api/stats` – Provides statistics about the collected IoT data (device count, message count, etc.).  
#### `MQTT-Service` (subscriber)
- Connects to RDS to **save** IoT data


### Amazon RDS PostgreSQL
- Multi-AZ deployment across `10.0.20.0/24` and `10.0.21.0/24`
- Endpoint:  
- Port: `5432`
- Secured to allow access only from EKS nodes

# Security

### Security Notes

- Private and database subnets have **no public IPs**.
- NAT Gateway allows outbound internet access from private subnets.
- RDS security group only accepts traffic from EKS worker nodes on port `5432`.
- IoT communication is secured using AWS IoT policies in written in terraform and certificates stored in EKS secrets.


Our current cloud-native infrastructure for the IoT data platform demonstrates a strong security posture built on several best practices across networking, identity, data handling, and containerization. Below is a summary of the key components:

### Network Security
- VPC Architecture isstructured with public, private, and database subnet separation. EKS nodes are shielded in private subnets; databases are further isolated.
- Security Groups follow the principle of least privilege, with tight ingress rules and specific allowances (e.g., only EKS nodes can access PostgreSQL on port 5432).
- Routing and Access are controlled via NAT Gateways and Internet Gateways properly restricted to public subnets, ensuring secure outbound traffic from private environments.

### Identity & Access Management
- IAM Roles are scoped with minimal privileges — both cluster and node roles use necessary AWS-managed policies.
- Kubernetes-AWS integration is securely configured through IAM authentication, preventing unauthorized cross-service access.

### Data & Secrets Security
- RDS Databases are located in private subnets, with encrypted connections enabled, daily backups configured.
- IoT Security is implemented via certificate-based device authentication and strict MQTT topic permissions.

### Container Security
- Minimal Base Images (`python:3.9-slim`, `node:18-alpine`) reduce the attack surface.
- Image Scanning is enabled in ECR.
- Readiness Probes & Health Checks are configured for API Gateway and MQTT services.
- Metrics endpoints and `/health` checks support observability and uptime monitoring.
- Mqtt certificates are stored in k8s certificates.

### Infrastructure & State Management
- Terraform State is secured in encrypted S3 buckets with locking via DynamoDB to prevent drift or accidental changes.
- Certificates & Secrets are managed as Kubernetes Secrets and mounted securely in containers as read-only volumes.

# Monitoring and Observability

## System Overview

The system monitors telemetry data from IoT devices (temperature and humidity sensors), which publish messages to AWS IoT Core via MQTT on the topic `sdk/test/python`.

The data is visualized in Grafana.

---

## Dashboard Metrics

![Dashboard Metrics](./docs/dashboard.png)


### 1. MQTT Message Rate
- Number of messages per second (topic: `sdk/test/python`)

### 2. Device Temperature
- Temperature readings from devices `my1`–`my4` (in °C)

### 3. Device Humidity
- Humidity readings from devices (in %)

### 4. Salmon Stress Index (custom metric)
- Calculated based on temperature and humidity
- Range: `0.0–1.0`
- Example formula:
  ```
  stress = 0.3 + 0.02 * (temp - 24) + 0.01 * (humidity - 40)
  ```

---

### Device Simulation

The `pub.sh` script simulates 4 devices (`my1`–`my4`) sending randomized data every second for 45 seconds.


# AWS cost estimates


### Assumptions for Using AWS Infrastructure
- **AWS IoT Core**: Connects 5 devices sending small messages (0.5 KB) every 5 minutes.  
- **ECR**: Stores our Docker images for easy deployment.  
---

### Estimated Traffic (Per Month)
- **IoT → AWS**: ~22 MB  
- **Internal forwarding (IoT → MQTT → DB)**: ~75 MB  
- **User API calls**: ~4 MB  
The setup is low-cost, scalable, and ready for real-world testing.

---

### Monthly Cost Breakdown (USD)

| **Component**                  | **Estimated Monthly Cost (USD)** | **Notes**                                                  |
|-------------------------------|----------------------------------|------------------------------------------------------------|
| NAT Gateway (hourly)          | 32.40                            | Hourly charge                                              |
| NAT Gateway (data)            | 0.45                             | Charge for processing 10 GB of data                        |
| EKS Cluster                   | 72.00                            | Hourly charge for the cluster                              |
| EC2 (2 × t3.medium)           | 59.90                            | Hourly charge for worker nodes                             |
| RDS DB Instance (db.t3.micro) | 11.52                            | Hourly charge                                              |
| RDS Storage (20 GB)           | 2.00                             | Monthly charge for EBS                                     |
| IoT Core Connectivity         | 0.02                             | 5 devices, running 24/7                                    |
| IoT Core Messaging            | 0.04                             | 43,200 messages                                            |
| IoT Core Rules Triggered      | 0.01                             | 43,200 rule executions                                     |
| IoT Core Actions Executed     | 0.01                             | 43,200 actions executed                                    |
| ECR Storage (10 GB)           | 1.00                             | Monthly charge                                             |
| API Gateway Requests          | <0.01                            | 400 requests/month                                         |
| API Gateway Data Out          | 0.35                             | 4 MB of data transfer                                      |
| **TOTAL**                     | **~179.70**                      | Excluding taxes and discounts                              |

---

### Optimized AWS Architecture Proposal
For a **small-scale IoT development or test environment**, you can significantly reduce costs with these changes:
- **Replace EKS** with **ECS Fargate**, which is easier to manage and **much cheaper** for small workloads.  
- Use only **one t3.small EC2 instance** (or even t3.micro) for any compute needs, instead of two t3.mediums.  
- **Remove the NAT Gateway** and use **VPC Endpoints** or **public subnets** with strict security groups.  


--------------------------------------------------------------------------------------------------------------------------------

# Step-by-step deployment guide

#### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/Zea.Task.git
cd Zea.Task
```

---

#### Step 2: Configure Terraform Variables

Navigate to the Terraform environment directory:

```bash
cd infrastructure/terraform/environments/dev
```

Create a `terraform.tfvars` file with your specific values:

```hcl
aws_region           = "us-east-1"
db_password          = "your-strong-password"
eks_cluster_name     = "iot-collector-dev-cluster"
iot_namespace        = "iot-system"
```

>  **Important**: Never commit your `terraform.tfvars` file if it contains sensitive values. Use GitHub Secrets if needed.

---

#### Step 3: Setting Up GitHub Secrets

In order for the CI/CD pipeline to deploy infrastructure and applications, you need to set AWS credentials as secrets:

1. Go to your GitHub repository.
2. Click on **Settings** → **Secrets and variables** → **Actions**.
3. Click **"New repository secret"**.
4. Add the following secrets:

```
Name: AWS_ACCESS_KEY_ID        Value: <your AWS access key>
Name: AWS_SECRET_ACCESS_KEY    Value: <your AWS secret key>
```

---

#### Step 4: Commit Changes

If you updated the `terraform.tfvars` or made any configuration changes, commit them to your **feature branch**:

```bash
git add .
git commit -m "Update Terraform variables"
git push origin my-feature-branch
```

Then, create a Pull Request into `prod` to trigger the GitHub Actions pipeline.

---

### Steps to Deploy the MQTT Service

#### 1. Create the namespace

If the namespace doesn't exist yet:

```bash
kubectl create namespace iot-system
```

---

#### 2. Create the MQTT certificates secret

Create a Kubernetes secret with the AWS IoT Core certificates.
Make sure the following files exist in your local directory:

- `./mqtt-service-python/certs/root-CA.crt`
- `./mqtt-service-python/certs/certificate.pem.crt`
- `./mqtt-service-python/certs/private.pem.key`

Now run:

```bash
kubectl create secret generic mqtt-certs \
  --namespace iot-system \
  --from-file=root-CA.crt=./mqtt-service-python/certs/root-CA.crt \
  --from-file=certificate.pem.crt=./mqtt-service-python/certs/certificate.pem.crt \
  --from-file=private.pem.key=./mqtt-service-python/certs/private.pem.key
```

---

#### 3. Create the database secret

Replace the placeholder with your actual connection string:

```bash
kubectl create secret generic db-secret \
  --namespace iot-system \
  --from-literal=DATABASE_URL="postgresql://username:password@hostname:5432/dbname"
```

---

#### 4. Apply the deployment manifest

Make sure the deployment YAML file is located at:

```
./mqtt-service-python/kubernetes/mqtt-service.yaml
```

Then apply it:

```bash
kubectl apply -f ./mqtt-service-python/kubernetes/mqtt-service.yaml
```


### Steps to Deploy the API Gateway

#### 1. Create the namespace (if not already created)

```bash
kubectl create namespace iot-system
```

---

#### 2. Create the database secret (if not already created)

```bash
kubectl create secret generic db-secret \
  --namespace iot-system \
  --from-literal=DATABASE_URL="postgresql://username:password@hostname:5432/dbname"
```

---

#### 3. Apply the deployment manifest

Ensure your deployment YAML is located at:

```
./kubernetes/api-gateway.yaml
```

Then apply it:

```bash
kubectl apply -f ./kubernetes/api-gateway.yaml
```

---

#### 4. Verify the deployment

```bash
kubectl get pods -n iot-system
kubectl describe deployment api-gateway -n iot-system
```

---

#### 5. Access the API Gateway

```bash
kubectl get svc api-gateway -n iot-system
```


#### Step 5: Monitor the Deployment

1. Go to the **"Actions"** tab in your GitHub repository.
2. Click on the running workflow to monitor progress.
3. Review the logs for each step to ensure everything is working correctly.
4. If any step fails, fix the issue in your branch and create a new PR.



### Step to Install Prometheus Stack and Dashboards

#### 1. Add Prometheus Helm repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

---

#### 2. Install Prometheus and Grafana using Helm

```bash
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/prometheus-values.yaml
```

> Make sure `monitoring/prometheus-values.yaml` exists and is properly configured.

---

#### 3. Apply ServiceMonitor resources

```bash
kubectl apply -f monitoring/api-gateway-monitor.yaml
kubectl apply -f monitoring/mqtt-service-monitor.yaml
```

---

#### 4. Import Dashboards

Make the import script executable and run it:

```bash
chmod +x monitoring/import-dashboards.sh
./monitoring/import-dashboards.sh
```

> This script will push predefined Grafana dashboards to the Prometheus stack (ensure Grafana is up and credentials are correct).