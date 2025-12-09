####################alb security group create####################
resource "aws_security_group" "iac-alb-sg" {
  vpc_id      = var.vpc_id
  name        = "iac-alb-sg" 
}

####################alb security group inboung rule create####################
resource "aws_security_group_rule" "iac-sg-alb-inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.iac-alb-sg.id
}

####################alb security group outboung rule create####################

resource "aws_security_group_rule" "mysgoutbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.iac-alb-sg.id

}
