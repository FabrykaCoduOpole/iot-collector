output "iot_endpoint" {
  description = "AWS IoT Core endpoint"
  value       = data.aws_iot_endpoint.current.endpoint_address
}

output "sample_sensor_name" {
  description = "Sample sensor thing name"
  value       = aws_iot_thing.sample_sensor.name
}

output "sample_sensor_certificate_pem" {
  description = "Sample sensor certificate PEM"
  value       = aws_iot_certificate.sample_sensor.certificate_pem
  sensitive   = true
}

output "sample_sensor_private_key" {
  description = "Sample sensor private key"
  value       = aws_iot_certificate.sample_sensor.private_key
  sensitive   = true
}

output "sample_sensor_public_key" {
  description = "Sample sensor public key"
  value       = aws_iot_certificate.sample_sensor.public_key
  sensitive   = true
}
