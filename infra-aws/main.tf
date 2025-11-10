# 1. Proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    project = "appfactory-hybrid"
    owner   = "pp09020"
    env     = "dev"
  }
}

# Sufijo aleatorio para evitar colisiones en recursos con nombre fijo
resource "random_id" "suffix" {
  byte_length = 2
}

# 2. AWS Lambda
# Archivo ZIP de la función
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../api-lambda"
  output_path = "lambda_function_payload.zip"
}

# Rol de IAM para Lambda (permiso básico de ejecución)
resource "aws_iam_role" "lambda_exec_role" {
  # Nombre con sufijo aleatorio para evitar conflictos en ejecuciones sin estado remoto
  name = "AppFactoryLambdaExecutionRole-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = local.common_tags
}

# Adjuntar política para CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Recurso Lambda Function
resource "aws_lambda_function" "api_lambda" {
  # Nombre con sufijo aleatorio para evitar conflictos en ejecuciones sin estado remoto
  function_name    = "AppFactoryProcessingAPI-${random_id.suffix.hex}" 
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 10
  environment {
    variables = {
      LAMBDA_API_KEY = var.lambda_api_key
    }
  }
  tags = local.common_tags
}

# 3. AWS API Gateway (API REST)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "AppFactoryHybridAPI"
  protocol_type = "HTTP"

  # Configuración CORS como bloque anidado (solucionado el error de recurso inválido)
  cors_configuration {
    allow_methods = ["*"]
    allow_origins = ["*"]
    allow_headers = ["content-type", "x-api-key"]
    max_age       = 300
  }
  tags = local.common_tags
}

# Integración Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.api_lambda.invoke_arn
  payload_format_version = "2.0"
}

# Ruta de la API (/process)
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /process" # Acepta cualquier método para evitar desajustes
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Despliegue (Stage)
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "prod" # Nombre de la etapa
  auto_deploy = true
}

# Permiso para que API Gateway invoque a Lambda
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
