data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo       = "${var.github_owner}/${var.github_repo}"
}

# ---------------------------------------------------------------------------
# 1. Cost guardrail – create this before anything else
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

# ---------------------------------------------------------------------------
# 2. Remote state bucket (Terraform >= 1.10 locks via S3 itself: use_lockfile)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project}-tfstate-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keep old state versions for 90 days only, so versioning never costs much
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ---------------------------------------------------------------------------
# 3. GitHub OIDC – no long-lived AWS keys stored in GitHub
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# --- Plan role: read-only, used by PR plans and the nightly drift check ------
data "aws_iam_policy_document" "plan_trust" {
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
      values = [
        "repo:${local.repo}:pull_request",         # PRs from branches in YOUR repo (forks never get OIDC tokens)
        "repo:${local.repo}:ref:refs/heads/main",  # scheduled drift detection on main
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.project}-gha-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan still needs to write the S3 lock file
data "aws_iam_policy_document" "state_rw" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "tfstate"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_rw.json
}

# --- Apply roles: one per GitHub Environment (dev, prod) --------------------
data "aws_iam_policy_document" "apply_trust" {
  for_each = var.environments

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
    # Only a job running in this GitHub Environment can assume the role,
    # so prod's required-reviewer gate protects prod credentials too.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:environment:${each.key}"]
    }
  }
}

# Least-privilege-ish: only the services this project uses, only resources
# named with the project prefix. If apply fails with AccessDenied, add the
# exact action from the error message – that's part of the learning.
data "aws_iam_policy_document" "apply" {
  source_policy_documents = [data.aws_iam_policy_document.state_rw.json]

  statement {
    sid     = "S3Site"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project}-*-site-*",
      "arn:aws:s3:::${var.project}-*-site-*/*",
    ]
  }
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.project}-*"]
  }
  statement {
    sid       = "Lambda"
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.project}-*"]
  }
  statement {
    sid       = "ApiGateway"
    actions   = ["apigateway:*"]
    resources = ["arn:aws:apigateway:${var.aws_region}::/*"]
  }
  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }
  statement {
    sid       = "Logs"
    actions   = ["logs:*"]
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${var.project}-*"]
  }
  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource"]
    resources = ["*"]
  }
  statement {
    sid = "IamProjectRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:TagRole", "iam:UntagRole", "iam:PassRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:UpdateAssumeRolePolicy",
    ]
    # gha-* roles are excluded on purpose: the pipeline can't edit its own permissions
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-dev-*",
      "arn:aws:iam::${local.account_id}:role/${var.project}-prod-*",
    ]
  }
}

resource "aws_iam_role" "apply" {
  for_each           = var.environments
  name               = "${var.project}-gha-apply-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.environments
  name     = "apply"
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.apply.json
}
