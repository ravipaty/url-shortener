output "tf_state_bucket" {
  description = "Set as GitHub repo variable TF_STATE_BUCKET"
  value       = aws_s3_bucket.tfstate.bucket
}

output "plan_role_arn" {
  description = "Set as GitHub repo variable PLAN_ROLE_ARN"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Set as APPLY_ROLE_ARN variable on each GitHub Environment"
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}
