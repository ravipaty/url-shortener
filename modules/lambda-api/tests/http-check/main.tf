# Helper module used only by the integration test
terraform {
  required_version = ">= 1.10"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

variable "url" {
  description = "Endpoint to POST to."
  type        = string
}

data "http" "post" {
  url             = var.url
  method          = "POST"
  request_headers = { content-type = "application/json" }
  request_body    = jsonencode({ url = "https://example.com" })

  retry {
    attempts     = 5
    min_delay_ms = 3000 # a brand-new API can take a few seconds to start answering
  }
}

output "status_code" {
  description = "HTTP status of the POST."
  value       = data.http.post.status_code
}

output "response_body" {
  description = "Response body of the POST."
  value       = data.http.post.response_body
}
