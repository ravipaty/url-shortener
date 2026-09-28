output "site_url" {
  description = "Public HTTPS URL of the site."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "bucket_name" {
  description = "Site bucket name."
  value       = aws_s3_bucket.site.bucket
}
