locals {
  bucket_rules       = [for r in var.rules : r if r.origin.type == "bucket"]
  target_group_rules = [for r in var.rules : r if r.origin.type != "bucket"]
}
