# Create ECR repository for MQTT service
resource "aws_ecr_repository" "mqtt_service" {
  name                 = "${var.project_name}-${var.environment}-mqtt-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mqtt-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create ECR repository for API Gateway
resource "aws_ecr_repository" "api_gateway" {
  name                 = "${var.project_name}-${var.environment}-api-gateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-gateway"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create lifecycle policy for ECR repositories
resource "aws_ecr_lifecycle_policy" "mqtt_service" {
  repository = aws_ecr_repository.mqtt_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "api_gateway" {
  repository = aws_ecr_repository.api_gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
