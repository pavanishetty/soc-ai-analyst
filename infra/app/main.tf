terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "soc-ai-analyst"
      ManagedBy = "terraform"
    }
  }
}

locals {
  name = "soc-ai-analyst"
}

data "aws_ecr_repository" "app" {
  name = local.name
}

# ---------- Logging ----------

resource "aws_cloudwatch_log_group" "app" {
  #checkov:skip=CKV_AWS_158:CloudWatch Logs encrypts log data by default; a customer-managed KMS key adds cost with little benefit here
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 365
}

# ---------- IAM role for the function ----------

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "app_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_role_policy" "app_logs" {
  name   = "write-own-logs"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_logs.json
}

data "aws_iam_policy_document" "app_tracing" {
  statement {
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "app_tracing" {
  name   = "write-traces"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_tracing.json
}

# ---------- The function ----------

resource "aws_lambda_function" "app" {
  #checkov:skip=CKV_AWS_116:Dead-letter queues only apply to asynchronous invocations; this function is only invoked synchronously via its URL
  #checkov:skip=CKV_AWS_117:The function needs no private network resources; a VPC would require a NAT gateway (about $30/month) for no security gain
  #checkov:skip=CKV_AWS_115:New AWS accounts have a 10-concurrency quota, so no concurrency can be reserved; spend is capped by budget alerts
  #checkov:skip=CKV_AWS_272:Lambda code signing only supports .zip packages, not container images; image integrity comes from immutable ECR tags and digest pinning
  function_name = local.name
  role          = aws_iam_role.app.arn
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.app.repository_url}@${var.image_digest}"
  architectures = ["x86_64"]
  memory_size   = 512
  timeout       = 30

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.app.name
  }

  depends_on = [aws_iam_role_policy.app_logs, aws_iam_role_policy.app_tracing]
}

# ---------- Public HTTPS endpoint ----------

resource "aws_lambda_function_url" "app" {
  #checkov:skip=CKV_AWS_258:Public demo API by design; it handles no user data, has no LLM key in the cloud, and spend is capped by budget alerts
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "public_url" {
  #checkov:skip=CKV_AWS_301:Required for a public function URL (auth type NONE); see the function URL justification
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "invoke_via_url" {
  #checkov:skip=CKV_AWS_301:Restricted to calls arriving via the function URL; required by Lambda since October 2025
  statement_id             = "AllowInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.app.function_name
  principal                = "*"
  invoked_via_function_url = true
}