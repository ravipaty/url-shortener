output "api_url" {
  description = "Base URL of the HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}
