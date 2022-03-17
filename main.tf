locals {
  rules = {
    for r in var.rules :
    join("-", concat(split(".", var.name), compact(split("/", r.prefix))))
    =>
    merge(r, tomap({ matcher = "${r.prefix}/*" }))
  }
}
