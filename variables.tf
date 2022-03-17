variable "name" {
  type = string
}

variable "domain_name" {
  type = string
}

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
    prefix  = string
    origin  = map(any)
    caching = bool
  }))

  validation {
    error_message = "The origin type is required."
    condition = alltrue([
      for r in var.rules :
      contains(keys(r.origin), "type")
    ])
  }

  validation {
    error_message = "The type of origin must be \"bucket\", \"virtual_machine\" or \"container\"."
    condition = alltrue([
      for r in var.rules :
      contains(["bucket", "virtual_machine", "container"], lookup(r.origin, "type", ""))
    ])
  }

  validation {
    error_message = "The origin port is required for type \"virtual_machine\"."
    condition = alltrue([
      for r in var.rules :
      contains(keys(r.origin), "port")
      if r.origin.type == "virtual_machine"
    ])
  }

  validation {
    error_message = "The prefix must begin and end with \"/\"."
    condition = alltrue([
      for r in var.rules :
      length(regexall("^/(.*/)?$", r.prefix)) > 0
    ])
  }

  validation {
    error_message = "The prefix \"/\" must be present to define the default routing rules."
    condition     = contains(var.rules.*.prefix, "/")
  }
}

#join("/", concat([""], compact(concat(split("/", "/media/"), ["*"]))))
