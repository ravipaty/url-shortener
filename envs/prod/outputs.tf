output "site_url" {
  description = "Frontend URL."
  value       = module.app.site_url
}

output "api_url" {
  description = "API base URL."
  value       = module.app.api_url
}
