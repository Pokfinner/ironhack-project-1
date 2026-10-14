
# ---------- SG: ALB (HTTP from the internet) ----------
resource "aws_security_group" "alb" {
  name        = "hserindik-voting-app-alb-sg"
  description = "HTTP from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hserindik-voting-app-alb-sg"
  }
}

# ---------- Application Load Balancer ----------
resource "aws_lb" "main" {
  name               = "hserindik-voting-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]

  tags = {
    Name = "hserindik-voting-alb"
  }
}

# ---------- Target groups ----------
resource "aws_lb_target_group" "vote" {
  name     = "hserindik-vote-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_target_group" "result" {
  name     = "hserindik-result-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

# ---------- Register server A in both target groups ----------
resource "aws_lb_target_group_attachment" "vote_a" {
  target_group_arn = aws_lb_target_group.vote.arn
  target_id        = aws_instance.frontend.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "result_a" {
  target_group_arn = aws_lb_target_group.result.arn
  target_id        = aws_instance.frontend.id
  port             = 8081
}

# ---------- Listener (port 80) and path rules ----------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found. Try /vote or /result"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "vote" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }

  condition {
    path_pattern {
      values = ["/vote", "/vote/*"]
    }
  }
}

resource "aws_lb_listener_rule" "result" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }

  condition {
    path_pattern {
      values = ["/result", "/result/*"]
    }
  }
}

# ---------- Extra rules for Vote ----------
# Vote uses absolute paths: its CSS is under /static/
resource "aws_lb_listener_rule" "vote_static" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }
}

# Vote's form sends the vote with POST to "/"
resource "aws_lb_listener_rule" "vote_form" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 16

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }
}