locals {
  bucket = one(aws_s3_bucket.default)
}

output "bucket" {
  value = {
    id  = local.bucket.id
    arn = local.bucket.arn
  }
}

output "application" {
  value = {
    for n, r in local.application_rules :
    n => {
      security_group = aws_security_group.default[r.origin.id].id
      target_group   = aws_lb_target_group.default[n].arn
    }
  }
}

output "distribution" {
  value = {
    arn            = aws_cloudfront_distribution.default.arn
    domain_name    = aws_cloudfront_distribution.default.domain_name
    hosted_zone_id = aws_cloudfront_distribution.default.hosted_zone_id
  }
}
