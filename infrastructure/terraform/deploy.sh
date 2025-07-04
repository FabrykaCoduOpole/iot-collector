#!/bin/bash

set -e

# Set variables
ENV=${1:-dev}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_DIR="$DIR/environments/$ENV"

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist!"
  exit 1
fi

# Setup remote state if it doesn't exist
if [ ! -f "$DIR/.remote-state-setup" ]; then
  echo "Setting up remote state..."
  $DIR/setup-remote-state.sh
  touch "$DIR/.remote-state-setup"
fi

# Navigate to environment directory
cd "$ENV_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan Terraform changes
echo "Planning Terraform changes..."
terraform plan -out=tfplan

# Apply Terraform changes
echo "Applying Terraform changes..."
terraform apply tfplan

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --region $(terraform output -raw aws_region) --name $(terraform output -raw eks_cluster_name)

# Build and push Docker images
echo "Building and pushing Docker images..."
MQTT_SERVICE_REPO=$(terraform output -raw ecr_mqtt_service_repository_url)
API_GATEWAY_REPO=$(terraform output -raw ecr_api_gateway_repository_url)

# Authenticate Docker with ECR
aws ecr get-login-password --region $(terraform output -raw aws_region) | docker login --username AWS --password-stdin $(echo $MQTT_SERVICE_REPO | cut -d'/' -f1)

# Build and push MQTT service image
docker build -t $MQTT_SERVICE_REPO:latest -f ../../../docker/mqtt-service/Dockerfile ../../../
docker push $MQTT_SERVICE_REPO:latest

# Build and push API Gateway image
docker build -t $API_GATEWAY_REPO:latest -f ../../../docker/api-gateway/Dockerfile ../../../
docker push $API_GATEWAY_REPO:latest

echo "Deployment complete!"
echo ""
echo "API Gateway endpoint: $(terraform output -raw api_gateway_endpoint 2>/dev/null || echo "Not available yet")"
echo ""
echo "To test the API Gateway, run:"
echo "curl http://$(terraform output -raw api_gateway_endpoint 2>/dev/null || echo "endpoint-not-available-yet")/health"
echo ""
echo "To test the MQTT service, use the AWS IoT Core console or the AWS CLI:"
echo "aws iot-data publish --topic 'sensors/device1/data' --payload '{\"deviceId\":\"device1\",\"temperature\":25.5,\"humidity\":60}' --qos 1"
