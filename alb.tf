// SG only meant for the alb to connect to the outside world
resource "aws_security_group" "alb" {
  vpc_id      = var.vpc_id
  name        = "${var.resource_prefix}-alb-${var.resource_suffix}"
  description = "Security group for the alb attached to the airflow ecs task"

  egress {
    description = "Allow all traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group_rule" "alb_outside_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "TCP"
  from_port         = var.use_https ? 443 : 80
  to_port           = var.use_https ? 443 : 80
  cidr_blocks       = var.ip_allow_list
}

// Give this SG to all the instances that want to connect to
// the airflow ecs task. For example rds and the alb
resource "aws_security_group" "airflow" {
  vpc_id      = var.vpc_id
  name        = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  description = "Security group to connect to the airflow instance"

  egress {
    description = "Allow all traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags

}

resource "aws_security_group_rule" "airflow_connection" {
  security_group_id        = aws_security_group.airflow.id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.airflow.id
}

// ALB
resource "aws_lb" "airflow" {
  name               = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id, aws_security_group.airflow.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = local.common_tags
}

resource "aws_lb_listener" "airflow" {
  load_balancer_arn = aws_lb.airflow.arn
  port              = var.use_https ? "443" : "80"
  protocol          = var.use_https ? "HTTPS" : "HTTP"
  certificate_arn   = var.use_https ? local.certificate_arn : ""

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}
