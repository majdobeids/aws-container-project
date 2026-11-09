resource "aws_security_group" "web" {
  name_prefix = "${var.project}-web-"
  description = "Allow admin SSH and application HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.http_cidr]
  }

  egress {
    description = "Outbound access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-web-sg"
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.project}-db-"
  description = "Allow admin SSH and PostgreSQL from web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description     = "PostgreSQL from web security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Outbound access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-db-sg"
  }
}
