variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "mqtt_service_url" {
  description = "URL of the MQTT service"
  type        = string
  default     = "https://example.com/mqtt"  # This will be updated later
}

variable "eks_cluster_id" {
  description = "EKS cluster ID"
  type        = string
}
