output "api_gateway_endpoint" {
  description = "URL del API Gateway (Host sin https://)"
  value       = replace(aws_apigatewayv2_api.http_api.api_endpoint, "https://", "")
}
