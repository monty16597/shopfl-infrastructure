output "function_name" {
  description = "Name of the created Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the created Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN used by API Gateway integrations."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN of the function execution role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the function execution role."
  value       = aws_iam_role.this.name
}

output "log_group_name" {
  description = "CloudWatch log group name for the function."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for the function."
  value       = aws_cloudwatch_log_group.this.arn
}
