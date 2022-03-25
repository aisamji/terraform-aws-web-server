locals {
  bucket_rules     = { for n, r in local.rules : n => r if r.origin.type == "bucket" }
  create_s3_origin = length(local.bucket_rules) > 0 ? 1 : 0
}

resource "aws_s3_bucket" "default" {
  count  = local.create_s3_origin
  bucket = var.name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "default" {
  count  = local.create_s3_origin
  bucket = aws_s3_bucket.default.0.bucket

  versioning_configuration {
    status = var.bucket_config.versioned ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_policy" "default" {
  count  = local.create_s3_origin
  bucket = aws_s3_bucket.default.0.bucket
  policy = templatefile("${path.module}/oai_access_policy.json", {
    BUCKET_ARN                 = aws_s3_bucket.default.0.arn,
    ORIGIN_ACCESS_IDENTITY_ARN = aws_cloudfront_origin_access_identity.default.0.iam_arn,
  })
}

resource "aws_cloudfront_origin_access_identity" "default" {
  count   = local.create_s3_origin
  comment = "${var.name} OAI to access S3 buckets."
}

resource "aws_s3_bucket_lifecycle_configuration" "default" {
  count  = local.create_s3_origin
  bucket = aws_s3_bucket.default.0.id

  rule {
    id = "delete-broken-uploads"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    status = "Enabled"
  }

  rule {
    id = "archive-retention"

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = max(1, var.bucket_config.retention_period)
    }

    status = var.bucket_config.versioned && var.bucket_config.retention_period > 0 ? "Enabled" : "Disabled"
  }
}
