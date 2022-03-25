locals {
  blank_bucket = {
    id  = null
    arn = null
  }
  bucket = try(aws_s3_bucket.default.0, null)
}

output "origins" {
  value = {
    application = {
      security_group = try(aws_security_group.default.0.id, null)
    }
    bucket = {
      id  = local.bucket.id
      arn = local.bucket.arn
    }
  }
}

output "endpoints" {
  value = {
    application = {
      for n, r in local.application_rules :
      r.prefix => {
        target_group = aws_lb_target_group.default[n].arn
      }
    }

    bucket = {
      for n, r in local.bucket_rules :
      r.prefix => {
        key = "${trimprefix(r.prefix, "/")}/"
        uri = "s3://${local.bucket.id}${r.prefix}/"
      }
    }
  }
}

output "domain_name" {
  value = aws_cloudfront_distribution.default.domain_name
}

output "hosted_zone_id" {
  value = aws_cloudfront_distribution.default.hosted_zone_id
}
