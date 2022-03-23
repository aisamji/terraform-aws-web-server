locals {
  use_custom_domain = var.certificate_arn != null
  snake_cased_name  = join("-", split(".", var.name))
  rules = {
    for r in var.rules :
    join("-", concat([local.snake_cased_name], compact(split("/", r.prefix))))
    =>
    merge(r, tomap({ matcher = r.prefix == "/" ? "*" : "${r.prefix}/*" }))
  }

  secret_token_header = "X-Cloudfront-Token"
}

resource "random_uuid" "token" {}
