resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Internet HTTP to ALB; outbound HTTP only to web instances"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "HTTP only from ALB; outbound for packages, GitHub and Systems Manager"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project_name}-web-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public campaign HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.web.id
  description                  = "Requests and health checks to web servers"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Only ALB may reach Apache"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id
  description       = "Outbound via NAT; no unsolicited inbound access"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
