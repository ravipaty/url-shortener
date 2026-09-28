variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "dev or prod."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "lambda_source_dir" {
  description = "Path to the Lambda source directory."
  type        = string
}

variable "index_template_path" {
  description = "Path to the index.html template."
  type        = string
}
