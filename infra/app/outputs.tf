output "function_url" {
  description = "Public HTTPS URL of the deployed API"
  value       = aws_lambda_function_url.app.function_url
}