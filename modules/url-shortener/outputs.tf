output "site_url" {
  description = "Frontend URL."
  value       = module.site.site_url
}

output "api_url" {
  description = "API base URL (short links live here)."
  value       = module.api.api_url
}
