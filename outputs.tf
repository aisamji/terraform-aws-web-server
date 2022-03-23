locals {
  bucket = one(aws_s3_bucket.default)
}

output "bucket" {
  value = {
    name = local.bucket.bucket
    arn  = local.bucket.arn
  }
}

output "application" {
  value = {
    server_security_group = one(aws_security_group.alb_to_server.*.id)
    target_group_arns = { for k, v in aws_lb_target_group.default :
      k => v.arn
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
