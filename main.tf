locals {
  http_port = 80
  any_port = 0
  any_protocol = -1
  tcp_protocol = "tcp"
  all_ips =  ["0.0.0.0/0"]
}




data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")
  vars = {
    server_port = var.server_port
    db_address = var.db_address
    db_port = var.db_port
  }
}

resource "aws_launch_configuration" "webserver" {
  image_id = "ami-02a599eb01e3b3c5b"
  instance_type = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data = data.template_file.user_data.rendered

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "webgroup" {
  launch_configuration = aws_launch_configuration.webserver.name
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns  = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"
  min_size = var.min_size
  max_size = var.max_size

  tag {
      key = "Name"
      value = "terraform-asg-example"
      propagate_at_launch  = true
  }
}

resource "aws_lb" "mylb" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default.ids
  security_groups = [aws_security_group.alb.id]
}


resource "aws_lb_listener" "http" {
  load_balancer_arn  = aws_lb.mylb.arn
  port = local.http_port
  protocol = "HTTP"
  default_action {
      type = "fixed-response"
      fixed_response {
          content_type = "text/plain"
          message_body = "404: page not found"
          status_code = 404
      }
  }
}

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
      field = "path-pattern"
      values = ["*"]
  }
  action {
      type = "forward"
      target_group_arn = aws_lb_target_group.asg.arn
  }
}



resource "aws_security_group" "instance" {
  name= "my-first-server-group"

}

resource "aws_security_group_rule" "server_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.instance.id
  from_port = var.server_port
  to_port = var.server_port
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips

}


resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

}

resource "aws_security_group_rule" "allow_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port = local.http_port
  to_port = local.http_port
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_http_outbound" {
  type = "egress"
  security_group_id = aws_security_group.alb.id
  from_port = local.http_port
  to_port = local.http_port
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips
}




data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}