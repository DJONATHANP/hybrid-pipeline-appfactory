variable "aws_region" {
  description = "Region de AWS para el despliegue."
  type        = string
  default     = "us-east-1" # Cambia a tu region preferida
}

variable "lambda_api_key" {
  description = "API Key requerida por la Lambda para autorizar llamadas."
  type        = string
  sensitive   = true
}
