resource "aws_security_group" "training" {
  #ts:skip=AC_AWS_0228 Public web server - HTTP must be reachable from the internet
  #checkov:skip=CKV_AWS_260:Public web server - HTTP must be reachable from the internet
  #checkov:skip=CKV_AWS_382:Instance needs outbound internet for apt packages (user_data)
  name        = "training"
  description = "Allow HTTP from internet and SSH from the admin server"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet (public web server)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  }

  ingress {
    description = "SSH only from the Terraform/Jenkins server"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "Outbound internet for package updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  tags = {
    Name = "training"
  }
}
