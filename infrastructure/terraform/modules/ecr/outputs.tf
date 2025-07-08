output "mqtt_service_repository_url" {
  description = "The URL of the MQTT service repository"
  value       = aws_ecr_repository.mqtt_service.repository_url
}

output "api_gateway_repository_url" {
  description = "The URL of the API Gateway repository"
  value       = aws_ecr_repository.api_gateway.repository_url
}

output "mqtt_service_repository_name" {
  description = "The name of the MQTT service repository"
  value       = aws_ecr_repository.mqtt_service.name
}

output "api_gateway_repository_name" {
  description = "The name of the API Gateway repository"
  value       = aws_ecr_repository.api_gateway.name
}

output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    mqtt_service = aws_ecr_repository.mqtt_service.repository_url
    api_gateway  = aws_ecr_repository.api_gateway.repository_url
  }
}
