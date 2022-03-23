locals {
  application_rules         = { for n, r in local.rules : n => r if r.origin.type == "application" }
  create_application_origin = length(local.application_rules) > 0 ? 1 : 0

  is_default_rule_application   = one([for n, r in local.application_rules : r if r.prefix == "/"]) != null
  non_default_application_rules = { for n, r in local.application_rules : n => r if r.prefix != "/" }
}

resource "aws_lb" "default" {
  count              = local.create_application_origin
  name               = local.snake_cased_name
  load_balancer_type = "application"
  subnets            = var.network_config.subnets
  security_groups    = [aws_security_group.cloudfront_to_alb.0.id]

  tags = var.tags
}

resource "aws_lb_listener" "default" {
  count = local.create_application_origin

  load_balancer_arn = aws_lb.default.0.arn
  port              = local.use_custom_domain ? 443 : 80
  protocol          = local.use_custom_domain ? "HTTPS" : "HTTP"
  ssl_policy        = local.use_custom_domain ? "ELBSecurityPolicy-2016-08" : null
  certificate_arn   = var.certificate_arn

  default_action {
    type             = local.is_default_rule_application ? "forward" : "fixed-response"
    target_group_arn = aws_lb_target_group.default[local.snake_cased_name].arn

    dynamic "fixed_response" {
      for_each = local.is_default_rule_application ? [] : ["run-it-dummy"]

      content {
        content_type = "text/plain"
        message_body = "Application Not Configured"
        status_code  = "500"
      }
    }
  }
}

resource "aws_lb_listener_rule" "default" {
  for_each = aws_lb_target_group.default

  listener_arn = aws_lb_listener.default.0.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  condition {
    path_pattern {
      values = [local.application_rules[each.key].matcher]
    }
  }
}

resource "aws_lb_target_group" "default" {
  for_each = local.application_rules

  name        = each.key
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.network_config.vpc_id
}

resource "aws_security_group" "cloudfront_to_alb" {
  count       = local.create_application_origin
  name_prefix = "cloudfront-to-alb"
  vpc_id      = var.network_config.vpc_id

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
}

resource "aws_security_group" "alb_to_server" {
  count       = local.create_application_origin
  name_prefix = "alb-to-server"
  vpc_id      = var.network_config.vpc_id

  tags = var.tags

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "tcp"
    security_groups = aws_security_group.cloudfront_to_alb.*.id
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
