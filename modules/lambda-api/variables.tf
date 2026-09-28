variable "name" {
  description = "Name for the function, role, log group and API."
  type        = string
}

variable "source_dir" {
  description = "Directory containing handler.py."
  type        = string
}

variable "table_name" {
  description = "DynamoDB table the function reads/writes."
  type        = string
}

variable "table_arn" {
  description = "ARN of that table (for the IAM policy)."
  type        = string
}

variable "cors_allow_origins" {
  description = "Origins allowed to call the API from a browser."
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 7
}

variable "throttle_burst" {
  description = "API burst limit (requests)."
  type        = number
  default     = 10
}

variable "throttle_rate" {
  description = "API steady-state limit (requests/second)."
  type        = number
  default     = 5
}
