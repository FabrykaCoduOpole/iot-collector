# IoT Data Collector System

## Overview

This project implements a scalable, secure microservice-based IoT Data Collector System that integrates with AWS cloud services. The system collects data from IoT devices via MQTT protocol, stores it in a database, and provides monitoring and observability capabilities.

## Architecture

### Architecture Diagram

```
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|  IoT Devices   +---->+  MQTT Broker   +---->+  Data Service  |
|                |     |                |     |                |
+----------------+     +----------------+     +-------+--------+
                                                     |
                                                     v
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|    Grafana     |<----+   Prometheus   |<----+   Database    |
|                |     |                |     |                |
+----------------+     +----------------+     +----------------+
```

### Components

#### Local Environment

| Component | Technology |
|-----------|------------|
| MQTT Broker | Mosquitto (Docker) |
| REST API Backend | Node.js |
| Database | MongoDB/PostgreSQL |
| Monitoring | Prometheus + Grafana |
| Kubernetes | minikube / kind |
| CI/CD | GitHub Actions |

#### AWS Cloud Environment

| Component | Technology |
|-----------|------------|
| MQTT Broker | AWS IoT Core |
| REST API Backend | Node.js (containerized) |
| Database | AWS RDS / DynamoDB |
| Monitoring | Prometheus + Grafana |
| Kubernetes | AWS EKS |
| Infrastructure as Code | Terraform / AWS CDK |
| CI/CD | GitHub Actions |

## Deployment Guide

### Prerequisites

- Docker and Docker Compose
- Kubernetes CLI (kubectl)
- minikube or kind (for local deployment)
- AWS CLI (for cloud deployment)
- Terraform or AWS CDK (for cloud deployment)

### Local Deployment

1. **Clone the repository**

```bash
git clone https://github.com/yourusername/iot-data-collector.git
cd iot-data-collector
```

2. **Start the local environment**

```bash
docker-compose up -d
```

3. **Deploy to local Kubernetes**

```bash
kubectl apply -f kubernetes/
```

4. **Access the services**

- MQTT Broker: localhost:1883
- REST API: localhost:3000
- Prometheus: localhost:9090
- Grafana: localhost:3000

### AWS Deployment

1. **Configure AWS credentials**

```bash
aws configure
```

2. **Deploy infrastructure using Terraform/CDK**

```bash
cd terraform
terraform init
terraform apply
```

3. **Deploy application to EKS**

```bash
kubectl apply -f kubernetes/
```

## Security Considerations

- **Network Security**: All services are deployed within private subnets with controlled access through security groups
- **Authentication**: MQTT broker requires client authentication
- **Authorization**: IAM roles for service-to-service communication
- **Data Encryption**: TLS for in-transit encryption, KMS for at-rest encryption
- **Secrets Management**: AWS Secrets Manager for credentials

## Monitoring and Observability

- **Metrics Collection**: All services expose metrics via `/metrics` endpoint
- **Prometheus**: Scrapes metrics from services
- **Grafana Dashboards**:
  - MQTT message rate
  - Database write operations
  - System resource utilization
  - API response times

## CI/CD Pipeline

The project uses GitHub Actions for continuous integration and deployment:

1. **Build**: Compile code and run tests
2. **Package**: Build Docker images
3. **Test**: Run integration tests
4. **Deploy**: Push to container registry and update Kubernetes deployments

## AWS Cost Estimates

| Service | Configuration | Monthly Cost Estimate |
|---------|---------------|------------------------|
| EKS | 1 cluster | $73 |
| EC2 (for EKS nodes) | 3 t3.medium instances | $90 |
| RDS | db.t3.small, 20GB storage | $30 |
| IoT Core | 1M messages/month | $10 |
| S3 | 10GB storage | $0.25 |
| CloudWatch | Basic monitoring | $15 |
| **Total** | | **~$218.25** |

## Development

### Project Structure

```
/
├── src/                  # Application source code
├── docker/               # Dockerfiles
├── kubernetes/           # Kubernetes manifests
├── terraform/            # Infrastructure as code
├── .github/workflows/    # CI/CD pipelines
└── docs/                 # Documentation
```

### Local Development

```bash
npm install
npm run dev
```

## Testing

```bash
npm test
```

## License

MIT