output "cloudfront_access_identity" {
  description = "Cloudfront Origin Access Identity which should be used by the cloudfront distribution to pull data from the S3 bucket"
  value       = aws_cloudfront_origin_access_identity.identity
}

output "bucket" {
  description = "The S3 bucket which contains content to serve"
  value       = aws_s3_bucket.bucket
}
