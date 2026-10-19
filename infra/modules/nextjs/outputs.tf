output "url" {
  value = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.app.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app.bucket
}