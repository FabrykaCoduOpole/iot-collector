# Create IoT Thing Type for sensors
resource "aws_iot_thing_type" "sensor" {
  name = "${var.project_name}-${var.environment}-sensor"
  
  properties {
    description = "IoT sensor device type for ${var.project_name}"
  }
}

# Create IoT Policy for sensors
resource "aws_iot_policy" "sensor_policy" {
  name = "${var.project_name}-${var.environment}-sensor-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
    Effect = "Allow"
    Action = [
    "iot:Connect"
    ]
    Resource = [
    "arn:aws:iot:*:*:client/${aws_iot_thing_type.sensor.name}*"
    ]
    },
    {
    Effect = "Allow"
    Action = [
    "iot:Publish"
    ]
    Resource = [
    "arn:aws:iot:*:*:topic/sensors/*/data",
    "arn:aws:iot:*:*:topic/sdk/test/python"
    ]
    },
    {
    Effect = "Allow"
    Action = [
    "iot:Subscribe"
    ]
    Resource = [
    "arn:aws:iot:*:*:topicfilter/sensors/*/data",
    "arn:aws:iot:*:*:topicfilter/sdk/test/python"
    ]
    },
    {
    Effect = "Allow"
    Action = [
    "iot:Receive"
    ]
    Resource = [
    "arn:aws:iot:*:*:topic/sensors/*/data",
    "arn:aws:iot:*:*:topic/sdk/test/python"
    ]
    }
    ]
  })
}

# // ... rest of code remains same

# Create a sample IoT thing for testing
resource "aws_iot_thing" "sample_sensor" {
  name = "${var.project_name}-${var.environment}-sample-sensor"
  
  thing_type_name = aws_iot_thing_type.sensor.name
  
  attributes = {
    model = "sample-sensor-v1"
  }
}

resource "aws_iot_certificate" "sample_sensor" {
  active = true
}

# Attach the policy to the certificate
resource "aws_iot_policy_attachment" "sample_sensor" {
  policy = aws_iot_policy.sensor_policy.name
  target = aws_iot_certificate.sample_sensor.arn
}

# Attach the certificate to the thing
resource "aws_iot_thing_principal_attachment" "sample_sensor" {
  thing     = aws_iot_thing.sample_sensor.name
  principal = aws_iot_certificate.sample_sensor.arn
}

# Create a rule to forward messages to the MQTT service
resource "aws_iot_topic_rule" "forward_to_mqtt_service" {
  name        = "${replace(var.project_name, "-", "_")}_${var.environment}_forward_to_mqtt_service"
  description = "Forward IoT messages to MQTT service"
  enabled     = true
  sql         = "SELECT * FROM 'sensors/+/data'"
  sql_version = "2016-03-23"

  http {
    url = var.mqtt_service_url
  }
}

# Get the AWS IoT endpoint
data "aws_iot_endpoint" "current" {
  endpoint_type = "iot:Data-ATS"
}

# # Create a ConfigMap for IoT Core endpoint
# resource "kubernetes_config_map" "iot_config" {
#   metadata {
#     name      = "iot-config"
#     namespace = "default"
#   }

#   data = {
#     iot-endpoint = data.aws_iot_endpoint.current.endpoint_address
#   }

#   depends_on = [var.eks_cluster_id]
# }
