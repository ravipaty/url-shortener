# Unit tests: plan only, mocked AWS – free, no credentials needed
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

variables {
  project             = "url-shortener"
  environment         = "dev"
  lambda_source_dir   = "../../app/src"
  index_template_path = "../../frontend/index.html.tftpl"
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "names_follow_convention" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = module.table.name == "url-shortener-prod-links"
    error_message = "Name must match the IAM prefix, or the apply role can't manage it."
  }
}
