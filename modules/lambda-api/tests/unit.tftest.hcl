# Unit tests: plan only, mocked AWS – free, no credentials needed
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}" # mocked data is random text otherwise, not valid JSON
    }
  }
}

variables {
  name       = "url-shortener-test"
  source_dir = "../../app/src"
  table_name = "t"
  table_arn  = "arn:aws:dynamodb:us-east-1:123456789012:table/t"
}

run "cheap_and_safe_defaults" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.architectures == tolist(["arm64"])
    error_message = "Use arm64 (cheaper)."
  }
  assert {
    condition     = aws_cloudwatch_log_group.lambda.retention_in_days <= 14
    error_message = "Logs must expire."
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit <= 10
    error_message = "Public API must be throttled."
  }
}
