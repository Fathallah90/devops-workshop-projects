resource "aws_lb" "my_alb" {
  name               = "alb-devops"
  internal           = false         #Creates an internet-facing ALB
  load_balancer_type = "application" #Application Layer (Layer 7) load balancer

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.my_public_subnet_us-east-1a.id,
    aws_subnet.my_public_subnet_us-east-1b.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "alb-devops-workshop"
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name        = "web-server-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web_servers_target_group"
  }
}

resource "aws_lb_listener" "my_http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}