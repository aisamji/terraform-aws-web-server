locals {
  bucket_rules                  = { for n, r in local.rules : n => r if r.origin.type == "bucket" }
  create_origin_access_identity = length(local.bucket_rules) > 0 ? 1 : 0
}

resource "aws_s3_bucket" "default" {
  for_each = local.bucket_rules
  bucket   = each.key
  tags     = var.tags
}

resource "aws_s3_bucket_versioning" "default" {
  for_each = aws_s3_bucket.default
  bucket   = each.key

  versioning_configuration {
    status = lookup(local.bucket_rules[each.key].origin, "versioned", true) ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_policy" "default" {
  for_each = aws_s3_bucket.default
  bucket   = each.key
  policy = templatefile("${path.module}/oai_access_policy.json", {
    BUCKET_ARN                 = each.value.arn,
    ORIGIN_ACCESS_IDENTITY_ARN = aws_cloudfront_origin_access_identity.default.0.iam_arn,
  })
}

resource "aws_cloudfront_origin_access_identity" "default" {
  count   = local.create_origin_access_identity
  comment = "${var.name} OAI to access S3 buckets."
}
