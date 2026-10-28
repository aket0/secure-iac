output "app_role_arn" {
  description = "Application IAM role ARN"
  value       = aws_iam_role.app.arn
}

output "app_role_name" {
  description = "Application IAM role name"
  value       = aws_iam_role.app.name
}
