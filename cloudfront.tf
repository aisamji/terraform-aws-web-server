locals {
  price_class        = "PriceClass_${var.price_class}"
  target_group_rules = []
  default_rule       = one([for n, r in local.rules : r if r.prefix == "/"])
  default_rule_name  = one([for n, r in local.rules : n if r.prefix == "/"])
  non_default_rules  = { for n, r in local.rules : n => r if r.prefix != "/" }
  cache_policies = {
    enabled  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    disabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }
  methods = {
    all     = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    options = ["GET", "HEAD", "OPTIONS"]
    default = ["GET", "HEAD"]
  }
}

resource "aws_cloudfront_distribution" "default" {

  dynamic "origin" {
    for_each = aws_s3_bucket.default
    iterator = bucket

    content {
      origin_id   = bucket.key
      domain_name = bucket.value.bucket_regional_domain_name

      s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.default.0.cloudfront_access_identity_path
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Distribution for ${var.name}"

  default_cache_behavior {
    allowed_methods  = lookup(local.default_rule, "allow_all_methods", false) ? local.methods.all : lookup(local.default_rule, "allow_options_method", false) ? local.methods.options : local.methods.default
    cached_methods   = lookup(local.default_rule, "cache_options_method", false) ? local.methods.options : local.methods.default
    target_origin_id = local.default_rule_name
    cache_policy_id  = local.default_rule.cached ? local.cache_policies["enabled"] : local.cache_policies["disabled"]

    viewer_protocol_policy = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.non_default_rules
    iterator = rule

    content {
      path_pattern     = rule.value.matcher
      allowed_methods  = lookup(rule.value, "allow_all_methods", false) ? local.methods.all : lookup(rule.value, "allow_options_method", false) ? local.methods.options : local.methods.default
      cached_methods   = lookup(rule.value, "cache_options_method", false) ? local.methods.options : local.methods.default
      target_origin_id = rule.key
      cache_policy_id  = rule.value.cached ? local.cache_policies["enabled"] : local.cache_policies["disabled"]

      viewer_protocol_policy = "redirect-to-https"

      dynamic "function_association" {
        for_each = rule.value.origin.type != "bucket" && lookup(rule.value.origin, "disable_rewrite", false) ? [] : [aws_cloudfront_function.rewrite[rule.key]]
        iterator = function

        content {
          event_type   = "viewer-request"
          function_arn = function.value.arn
        }
      }
    }
  }

  price_class = local.price_class

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.type
      locations        = var.geo_restriction.locations
    }
  }

  tags = var.tags

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_function" "rewrite" {
  for_each = local.non_default_rules
  name     = each.key
  runtime  = "cloudfront-js-1.0"
  code = templatefile("${path.module}/rewrite_url.js", {
    PREFIX = each.value.prefix
  })
}
