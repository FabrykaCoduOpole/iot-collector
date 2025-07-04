terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  backend "s3" {
    bucket         = "iot-collector-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "iot-collector-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Import VPC module
module "vpc" {
  source = "../../modules/vpc"
  
  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# Import EKS module
module "eks" {
  source = "../../modules/eks"
  
  environment  = var.environment
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
}

# Import RDS module
module "rds" {
  source = "../../modules/rds"
  
  environment     = var.environment
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.database_subnet_ids
  eks_sg_id       = module.eks.node_security_group_id
  eks_cluster_id  = module.eks.cluster_name
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = var.db_password
}

# Import IoT Core module
module "iot" {
  source = "../../modules/iot"
  
  environment     = var.environment
  project_name    = var.project_name
  mqtt_service_url = var.mqtt_service_url
  eks_cluster_id  = module.eks.cluster_name
}

# Import ECR module
module "ecr" {
  source = "../../modules/ecr"
  
  environment  = var.environment
  project_name = var.project_name
}

# Configure kubectl provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"  # Upewnij się, że używasz v1beta1, a nie v1alpha1
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
