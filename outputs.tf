locals {
  bucket = one(aws_s3_bucket.default)
}

output "bucket" {
  value = {
    name = local.bucket.bucket
    arn  = local.bucket.arn
  }
}

output "distribution" {
  value = {
    arn            = aws_cloudfront_distribution.default.arn
    domain_name    = aws_cloudfront_distribution.default.domain_name
    hosted_zone_id = aws_cloudfront_distribution.default.hosted_zone_id
  }
}
