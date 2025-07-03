terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Uncomment this block if you want to use Terraform Cloud or S3 backend
  # backend "s3" {
  #   bucket = "iot-collector-terraform-state"
  #   key    = "dev/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Import modules
module "vpc" {
  source = "../../modules/vpc"
  
  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# The rest of the modules will be added in subsequent steps
