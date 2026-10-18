output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state for the app infrastructure"
  value       = aws_s3_bucket.tf_state.bucket
}

output "ecr_repository_url" {
  description = "ECR repository the pipeline pushes images to"
  value       = aws_ecr_repository.app.repository_url
}

output "github_deploy_role_arn" {
  description = "IAM role the GitHub deploy job assumes via OIDC"
  value       = aws_iam_role.github_deploy.arn
}