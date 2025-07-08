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

echo "Deployment complete!"
echo ""
echo "RDS Endpoint: $(terraform output -raw rds_endpoint)"
echo "IoT Endpoint: $(terraform output -raw iot_endpoint)"
echo ""
echo "To test the MQTT service, use the AWS IoT Core console or the AWS CLI:"
echo "aws iot-data publish --topic 'sensors/device1/data' --payload '{\"deviceId\":\"device1\",\"temperature\":25.5,\"humidity\":60}' --qos 1"
