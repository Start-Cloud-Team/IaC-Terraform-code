resource "aws_security_group" "iac-alb-sg" {
  vpc_id      = aws_vpc.iac-vpc.id
  name        = "iac-alb-sg" 
}

resource "aws_security_group_rule" "iac-sg-alb-inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.iac-alb-sg.id
}
 
resource "aws_security_group_rule" "mysgoutbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.iac-alb-sg.id
}
