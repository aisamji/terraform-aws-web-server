variable "price_class" {
  type        = string
  description = "Limit the edge locations used to save on costs. See https://aws.amazon.com/cloudfront/pricing/ for details."
  default     = "All"

  validation {
    error_message = "Price class must be \"All\", \"200\", or \"100\"."
    condition     = contains(["All", "200", "100"], var.price_class)
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "rules" {
  type = list(object({
    prefix = string
    origin = map(any)
    cached = bool
  }))

  validation {
    error_message = "The origin type is required."
    condition = alltrue([
      for r in var.rules :
      contains(keys(r.origin), "type")
    ])
  }

  validation {
    error_message = "The type of origin must be \"bucket\" or \"application\"."
    condition = alltrue([
      for r in var.rules :
      contains(["bucket", "application"], lookup(r.origin, "type", ""))
    ])
  }

  validation {
    error_message = "The prefix must begin with and must not end with \"/\"."
    condition = alltrue([
      for r in var.rules :
      length(regexall("^/(?:.*[^/])?$", r.prefix)) > 0
    ])
  }

  validation {
    error_message = "The prefix \"/\" must be present to define the default routing rules."
    condition     = contains(var.rules.*.prefix, "/")
  }
}

variable "geo_restriction" {
  type = object({
    type      = string
    locations = list(string)
  })

  default = {
    type      = "none"
    locations = []
  }

  validation {
    error_message = "The restriction type must be one of \"none\", \"whitelist\", or \"blacklist\"."
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction.type)
  }
}

variable "name" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "network_config" {
  type = object({
    vpc_id  = string
    subnets = list(string)
  })
  default = null
}
