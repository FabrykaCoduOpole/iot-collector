output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "rds_connection_string" {
  description = "Database connection string"
  value       = module.rds.db_connection_string
  sensitive   = true
}

output "iot_endpoint" {
  description = "AWS IoT Core endpoint"
  value       = module.iot.iot_endpoint
}

output "sample_sensor_name" {
  description = "Sample sensor thing name"
  value       = module.iot.sample_sensor_name
}

output "sample_sensor_certificate_pem" {
  description = "Sample sensor certificate PEM"
  value       = module.iot.sample_sensor_certificate_pem
  sensitive   = true
}

output "sample_sensor_private_key" {
  description = "Sample sensor private key"
  value       = module.iot.sample_sensor_private_key
  sensitive   = true
}

output "ecr_mqtt_service_repository_url" {
  description = "ECR repository URL for MQTT service"
  value       = module.ecr.mqtt_service_repository_url
}

output "ecr_api_gateway_repository_url" {
  description = "ECR repository URL for API Gateway"
  value       = module.ecr.api_gateway_repository_url
}

output "ecr_repository_urls" {
  description = "Map of repository names to URLs"
  value       = module.ecr.repository_urls
}

output "docker_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.ecr.mqtt_service_repository_url)[0]}"
}


output "db_username" {
  description = "Database username"
  value       = var.db_username
}

output "db_password" {
  description = "Database password"
  value       = var.db_password
  sensitive   = true
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}
