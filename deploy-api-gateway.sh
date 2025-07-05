#!/bin/bash

set -e

# Przejdź do katalogu Terraform
cd /Users/kakf/Projects/Zea.Task/infrastructure/terraform/environments/dev

# Pobierz URL repozytorium ECR
API_GATEWAY_REPO=$(terraform output -raw ecr_api_gateway_repository_url)
echo "API Gateway Repo: $API_GATEWAY_REPO"

# Zaloguj się do ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(echo $API_GATEWAY_REPO | cut -d'/' -f1)

# Przejdź do głównego katalogu projektu
cd /Users/kakf/Projects/Zea.Task

# Zbuduj i wypchnij obraz Docker
echo "Budowanie i wypychanie obrazu API Gateway..."
docker build -t $API_GATEWAY_REPO -f ./docker/api-gateway/Dockerfile .
docker push $API_GATEWAY_REPO

# Skonfiguruj kubectl
echo "Konfigurowanie kubectl..."
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw eks_cluster_name)

# Utwórz namespace dla aplikacji (jeśli jeszcze nie istnieje)
echo "Tworzenie namespace iot-system..."
kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -

# Pobierz dane do połączenia z bazą danych
DB_USERNAME=$(terraform output -raw db_username)
DB_PASSWORD=$(terraform output -raw db_password)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
DB_NAME=$(terraform output -raw db_name)

# Utwórz sekret dla bazy danych
echo "Tworzenie sekretu dla bazy danych..."
kubectl create secret generic db-secret -n iot-system \
  --from-literal=DATABASE_URL="postgres://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}/${DB_NAME}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Utwórz plik manifestu
echo "Tworzenie pliku manifestu Kubernetes..."
mkdir -p kubernetes

cat > kubernetes/api-gateway.yaml << EOFINNER
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: iot-system
  labels:
    app: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/metrics"
        prometheus.io/port: "3000"
    spec:
      containers:
      - name: api-gateway
        image: ${API_GATEWAY_REPO}
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DATABASE_URL
        - name: PORT
          value: "3000"
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 2
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 2
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: iot-system
  labels:
    app: api-gateway
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "3000"
spec:
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 3000
    name: http
  type: LoadBalancer
EOFINNER

# Wdróż API Gateway
echo "Wdrażanie API Gateway..."
kubectl apply -f kubernetes/api-gateway.yaml

# Poczekaj, aż pody będą gotowe
echo "Czekam, aż pody będą gotowe..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n iot-system --timeout=300s || true

# Pobierz endpoint API Gateway
API_ENDPOINT=$(kubectl get svc -n iot-system api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Wdrożenie zakończone!"
echo "API Gateway dostępny pod adresem: http://$API_ENDPOINT"
echo ""
echo "Aby przetestować API Gateway, wykonaj:"
echo "curl http://$API_ENDPOINT/health"
echo "curl http://$API_ENDPOINT/api/stats"
echo "curl http://$API_ENDPOINT/api/devices"
echo "curl http://$API_ENDPOINT/api-docs"
