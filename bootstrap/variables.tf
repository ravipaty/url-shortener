variable "aws_region" {
  description = "Region for the state bucket and all stacks."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix for every resource. IAM permissions are scoped to this prefix."
  type        = string
  default     = "url-shortener"
}

variable "github_owner" {
  description = "Your GitHub username (or org)."
  type        = string
}

variable "github_repo" {
  description = "Repository name, without the owner."
  type        = string
}

variable "budget_email" {
  description = "Email that receives AWS Budget alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD. Alerts fire at 50% and 100%."
  type        = string
  default     = "5"
}

variable "environments" {
  description = "GitHub Environments that get their own apply role."
  type        = set(string)
  default     = ["dev", "prod"]
}
