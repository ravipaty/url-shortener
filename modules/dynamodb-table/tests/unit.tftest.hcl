# Unit tests: plan only, mocked AWS – free, no credentials needed
mock_provider "aws" {}

variables {
  name = "url-shortener-test-links"
}

run "on_demand_and_no_pitr_by_default" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST"
    error_message = "Table must be on-demand to stay cheap."
  }
  assert {
    condition     = aws_dynamodb_table.this.point_in_time_recovery[0].enabled == false
    error_message = "PITR should be off unless asked for."
  }
}

run "pitr_can_be_enabled" {
  command = plan

  variables {
    point_in_time_recovery = true
  }

  assert {
    condition     = aws_dynamodb_table.this.point_in_time_recovery[0].enabled
    error_message = "PITR flag was ignored."
  }
}
