output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state for the app infrastructure"
  value       = aws_s3_bucket.tf_state.bucket
}