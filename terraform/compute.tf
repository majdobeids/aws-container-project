data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "admin" {
  key_name_prefix = "${var.project}-"
  public_key      = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "node" {
  for_each = toset(["web", "db"])

  ami           = nonsensitive(data.aws_ssm_parameter.ubuntu.value)
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.admin.key_name

  vpc_security_group_ids = [
    each.key == "web" ? aws_security_group.web.id : aws_security_group.db.id
  ]

  iam_instance_profile = each.key == "db" ? aws_iam_instance_profile.db.name : null

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "${var.project}-${each.key}"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy.backup
  ]

  lifecycle {
    ignore_changes = [ami]
  }
}
