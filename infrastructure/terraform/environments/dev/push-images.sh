#!/bin/bash

# Get ECR repository URLs from Terraform outputs
MQTT_SERVICE_REPO=$(terraform output -raw ecr_mqtt_service_repository_url)
API_GATEWAY_REPO=$(terraform output -raw ecr_api_gateway_repository_url)
AWS_REGION=$(terraform output -raw aws_region || echo "us-east-1")

# Authenticate Docker with ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $MQTT_SERVICE_REPO | cut -d'/' -f1)

# Build and push MQTT service image
echo "Building and pushing MQTT service image..."
docker build -t $MQTT_SERVICE_REPO:latest -f ../../../../docker/mqtt-service/Dockerfile ../../../../
docker push $MQTT_SERVICE_REPO:latest

# Build and push API Gateway image
echo "Building and pushing API Gateway image..."
docker build -t $API_GATEWAY_REPO:latest -f ../../../../docker/api-gateway/Dockerfile ../../../../
docker push $API_GATEWAY_REPO:latest

echo "Done!"
