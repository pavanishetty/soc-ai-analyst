# Lets GitHub Actions log in to AWS with short-lived tokens instead of stored keys.

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as owner/name"
  type        = string
  default     = "pavanishetty/soc-ai-analyst"
}

variable "github_environment" {
  description = "GitHub environment whose jobs may assume the deploy role"
  type        = string
  default     = "production"
}

data "aws_region" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${local.app_name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  function_arn = "arn:aws:lambda:${data.aws_region.current.region}:${local.account_id}:function:${local.app_name}"
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushAndRead"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListTagsForResource",
      "ecr:PutImage",
      "ecr:SetRepositoryPolicy",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tf_state.arn]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tf_state.arn}/app/*"]
  }

  statement {
    sid       = "ManageOnlyThisFunction"
    actions   = ["lambda:*"]
    resources = [local.function_arn, "${local.function_arn}:*"]
  }

  statement {
    sid       = "PassOnlyTheFunctionRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.app.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}