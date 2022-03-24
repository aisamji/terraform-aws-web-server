locals {
  application_rules = {
    for n, r in local.rules : n => r if r.origin.type == "application"
  }

  create_application_origin = length(local.application_rules) > 0 ? 1 : 0
}

data "aws_subnet" "default" {
  count = local.create_application_origin
  id    = var.loadbalancer_config.subnet_ids.0
}

resource "aws_lb" "default" {
  count = local.create_application_origin

  name               = local.snake_cased_name
  load_balancer_type = "application"
  subnets            = var.loadbalancer_config.subnet_ids
  security_groups    = [aws_security_group.default.0.id]

  tags = var.tags
}

resource "aws_lb_listener" "default" {
  count = local.create_application_origin

  load_balancer_arn = aws_lb.default.0.arn
  port              = local.use_custom_domain ? 443 : 80
  protocol          = local.use_custom_domain ? "HTTPS" : "HTTP"
  certificate_arn   = var.certificate_arn

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

  listener_arn = aws_lb_listener.default.0.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.matcher]
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
  port        = lookup(each.value.origin, "server_port", "80")
  protocol    = "HTTP"
  target_type = lookup(each.value.origin, "server_type", "ip")
  vpc_id      = data.aws_subnet.default.0.vpc_id
}

resource "aws_security_group" "default" {
  count  = local.create_application_origin
  name   = local.snake_cased_name
  vpc_id = data.aws_subnet.default.0.vpc_id

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
