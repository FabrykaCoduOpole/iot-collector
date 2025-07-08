#!/bin/bash

# Set variables
AWS_REGION="us-east-1"
STATE_BUCKET="iot-collector-terraform-state"
LOCK_TABLE="iot-collector-terraform-locks"

# Create S3 bucket for remote state
echo "Creating S3 bucket for remote state..."
aws s3api create-bucket \
  --bucket $STATE_BUCKET \
  --region $AWS_REGION

# Enable versioning on the S3 bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket $STATE_BUCKET \
  --versioning-configuration Status=Enabled

# Enable server-side encryption on the S3 bucket
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
  --bucket $STATE_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name $LOCK_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

echo "Remote state setup complete!"
echo "Use the following backend configuration in your Terraform files:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$STATE_BUCKET\""
echo "    key            = \"dev/terraform.tfstate\""
echo "    region         = \"$AWS_REGION\""
echo "    dynamodb_table = \"$LOCK_TABLE\""
echo "    encrypt        = true"
echo "  }"
echo "}"
