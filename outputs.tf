output "buckets" {
  value = {
    for k, b in aws_s3_bucket.default :
    local.rules[k].prefix => b.bucket
  }
}
