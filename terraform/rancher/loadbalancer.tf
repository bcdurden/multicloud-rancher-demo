# API server LB
resource "aws_lb" "apiserver_lb" {
  name               = "${var.prefix}-apiserver-lb"
  load_balancer_type = "network"

  subnets            = var.subnet_ids

  tags = {
    owner = "brian"
    KeepRunning = "true"
  }
}

resource "aws_lb_target_group" "apiserver_lb_6443_tg" {
  name     = "${var.prefix}-apiserver-6443"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}
resource "aws_lb_target_group" "apiserver_lb_443_tg" {
  name     = "${var.prefix}-apiserver-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.apiserver_lb.arn
  port              = "6443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apiserver_lb_6443_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "apiserver_lg_attach_6443" {
  target_group_arn = aws_lb_target_group.apiserver_lb_6443_tg.arn
  target_id        = aws_instance.rancher_server_master.id
  port             = 6443
}
resource "aws_lb_target_group_attachment" "apiserver_lg_attach_443" {
  target_group_arn = aws_lb_target_group.apiserver_lb_443_tg.arn
  target_id        = aws_instance.rancher_server_master.id
  port             = 443
}

# rancher ingress LB
resource "aws_lb" "ingress_lb" {
  name               = "${var.prefix}-ingress-lb"
  load_balancer_type = "network"

  subnets            = var.subnet_ids

  tags = {
    owner = "brian"
    KeepRunning = "true"
  }
}

resource "aws_lb_target_group" "ingress_lb_80_tg" {
  name     = "${var.prefix}-ingress-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id
}
resource "aws_lb_target_group" "ingress_lb_443_tg" {
  name     = "${var.prefix}-ingress-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "ingress_front_end_443" {
  load_balancer_arn = aws_lb.ingress_lb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_lb_443_tg.arn
  }
}
resource "aws_lb_listener" "ingress_front_end_80" {
  load_balancer_arn = aws_lb.ingress_lb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_lb_80_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "ingress_lg_attach_443" {
  count = var.worker_count

  target_group_arn = aws_lb_target_group.ingress_lb_443_tg.arn
  target_id        = aws_instance.rancher_server_workers[count.index].id
  port             = 443
}
resource "aws_lb_target_group_attachment" "ingress_lg_attach_80" {
  count = var.worker_count
  
  target_group_arn = aws_lb_target_group.ingress_lb_80_tg.arn
  target_id        = aws_instance.rancher_server_workers[count.index].id
  port             = 80
}