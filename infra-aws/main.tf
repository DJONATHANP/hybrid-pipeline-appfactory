# 1. Proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 2. AWS Lambda
# Archivo ZIP de la funci�n
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../api-lambda"
  output_path = "lambda_function_payload.zip"
}

# Rol de IAM para Lambda (permiso b�sico de ejecuci�n)
resource "aws_iam_role" "lambda_exec_role" {
  name = "AppFactoryLambdaExecutionRole-PROD" 
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
}

# Adjuntar politica para CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Recurso Lambda Function
resource "aws_lambda_function" "api_lambda" {
  function_name    = "AppFactoryProcessingAPI-PROD"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 10
}

# 3. AWS API Gateway (API REST)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "AppFactoryHybridAPI"
  protocol_type = "HTTP"

  # CORRECCIÓN: Configuración CORS como bloque anidado
  cors_configuration {
    allow_methods = ["*"]
    allow_origins = ["*"]
    allow_headers = ["content-type", "x-api-key"]
    max_age       = 300
  }
}

# Integracion Lambda
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
  route_key = "GET /process" # Ruta para la llamada fetch
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
