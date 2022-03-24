locals {
  application_rules = {
    for n, r in local.rules : n => r if r.origin.type == "application"
  }

  application_origins = distinct([for n, r in local.application_rules : r.origin.id])
  application_rules_grouped_by_origin_id = {
    for n, r in local.application_rules :
    r.origin.id => {
      subnets = r.origin.subnets
    }
  }
  partial_application_origin_info = zipmap(keys(local.application_rules_grouped_by_origin_id), matchkeys(values(local.application_rules_grouped_by_origin_id), keys(local.application_rules_grouped_by_origin_id), local.application_origins))
  application_origin_info = {
    for n, i in local.partial_application_origin_info :
    n => merge(
      i,
      {
        vpc       = data.aws_subnet.default[n].vpc_id
        safe_name = substr(join("-", [local.snake_cased_name, md5(data.aws_subnet.default[n].vpc_id)]), 0, 32)
      }
    )
  }
}

data "aws_subnet" "default" {
  for_each = local.partial_application_origin_info
  id       = each.value.subnets.0
}

resource "aws_lb" "default" {
  for_each = local.application_origin_info

  name               = each.value.safe_name
  load_balancer_type = "application"
  subnets            = each.value.subnets
  security_groups    = [aws_security_group.default[each.key].id]

  tags = var.tags
}

resource "aws_lb_listener" "default" {
  for_each = aws_lb.default

  load_balancer_arn = each.value.arn
  port              = local.use_custom_domain ? 443 : 80
  protocol          = local.use_custom_domain ? "HTTPS" : "HTTP"
  # ssl_policy        = local.use_custom_domain ? "ELBSecurityPolicy-2016-08" : null
  certificate_arn = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<html><head><title>${var.name}</title></head><body><h1>Request not authorized</h1></body></html>"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "default" {
  for_each = local.application_rules

  listener_arn = aws_lb_listener.default[each.value.origin.id].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default[each.key].arn
  }

  condition {
    path_pattern {
      values = [local.application_rules[each.key].matcher]
    }
  }

  condition {
    http_header {
      http_header_name = local.secret_token_header
      values           = [random_uuid.token.result]
    }
  }
}

resource "aws_lb_target_group" "default" {
  for_each = local.application_rules

  name        = each.key
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_subnet.default[each.value.origin.id].vpc_id
}

resource "aws_security_group" "default" {
  for_each = local.application_origin_info
  name     = each.value.safe_name
  vpc_id   = each.value.vpc

  tags = var.tags

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
