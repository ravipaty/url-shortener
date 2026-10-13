# Integration test: creates REAL resources in AWS, calls the API, then destroys
# everything. Needs the dev apply role (see .github/workflows/integration.yml).
provider "aws" {
  region = "us-east-1"
}

run "table" {
  module {
    source = "../dynamodb-table"
  }
  variables {
    name = "url-shortener-dev-itest-links"
  }
}

run "api" {
  variables {
    name       = "url-shortener-dev-itest" # must match the dev apply role's name prefix
    source_dir = "../../app/src"
    table_name = run.table.name
    table_arn  = run.table.arn
  }
}

run "create_link_returns_201" {
  module {
    source = "./tests/http-check"
  }
  variables {
    url = "${trimsuffix(run.api.api_url, "/")}/links"
  }

  assert {
    condition     = output.status_code == 201
    error_message = "POST /links failed: ${output.response_body}"
  }
}
