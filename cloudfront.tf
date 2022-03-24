locals {
  price_class       = "PriceClass_${var.price_class}"
  default_rule      = one([for n, r in local.rules : r if r.prefix == "/"])
  non_default_rules = { for n, r in local.rules : n => r if r.prefix != "/" }

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
      origin_id   = "bucket"
      domain_name = bucket.value.bucket_regional_domain_name

      s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.default.0.cloudfront_access_identity_path
      }
    }
  }

  dynamic "origin" {
    for_each = aws_lb.default
    iterator = loadbalancer

    content {
      origin_id   = "application"
      domain_name = loadbalancer.value.dns_name

      custom_header {
        name  = local.secret_token_header
        value = random_uuid.token.result
      }

      custom_origin_config {
        http_port  = 80
        https_port = 443

        origin_protocol_policy = local.use_custom_domain ? "https-only" : "http-only"
        origin_ssl_protocols   = ["TLSv1"]
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Distribution for ${var.name}"

  default_cache_behavior {
    allowed_methods  = lookup(local.default_rule, "allow_all_methods", false) ? local.methods.all : lookup(local.default_rule, "allow_options_method", false) ? local.methods.options : local.methods.default
    cached_methods   = lookup(local.default_rule, "cache_options_method", false) ? local.methods.options : local.methods.default
    target_origin_id = local.default_rule.origin.type

    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    forwarded_values {
      headers      = local.default_rule.origin.type == "application" ? ["Host", "Origin"] : []
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.non_default_rules
    iterator = rule

    content {
      path_pattern     = rule.value.matcher
      allowed_methods  = lookup(rule.value, "allow_all_methods", false) ? local.methods.all : lookup(rule.value, "allow_options_method", false) ? local.methods.options : local.methods.default
      cached_methods   = lookup(rule.value, "cache_options_method", false) ? local.methods.options : local.methods.default
      target_origin_id = rule.value.origin.type

      viewer_protocol_policy = "redirect-to-https"

      min_ttl     = 0
      default_ttl = 3600
      max_ttl     = 86400

      forwarded_values {
        headers      = rule.value.origin.type == "application" ? ["Host", "Origin"] : []
        query_string = true

        cookies {
          forward = "all"
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

  aliases = local.use_custom_domain ? [var.name] : []

  viewer_certificate {
    cloudfront_default_certificate = !local.use_custom_domain
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
  }
}
