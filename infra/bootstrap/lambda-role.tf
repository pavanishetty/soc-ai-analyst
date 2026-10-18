# The Lambda function's own identity. It lives in the bootstrap layer so that
# only a human applying bootstrap can change what the function is allowed to do.
# The deploy pipeline can use this role, but never modify it.

locals {
  app_name           = "soc-ai-analyst"
  app_log_group_name = "/aws/lambda/${local.app_name}"
}

resource "aws_cloudwatch_log_group" "app" {
  #checkov:skip=CKV_AWS_158:CloudWatch Logs encrypts log data by default; a customer-managed KMS key adds cost with little benefit here
  name              = local.app_log_group_name
  retention_in_days = 365
}

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
  name               = "${local.app_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }

  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "runtime"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}