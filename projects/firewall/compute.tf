resource "aws_security_group" "spoke_test" {
  for_each = local.spokes

  description = "Test instance traffic for the centralized inspection lab"
  name        = "${local.name_prefix}-${each.value.display}-test"
  vpc_id      = aws_vpc.spoke[each.key].id

  dynamic "ingress" {
    for_each = var.allow_spoke_icmp ? [1] : []

    content {
      cidr_blocks = values(var.spoke_vpc_cidrs)
      description = "ICMP between the two authorized spoke VPCs"
      from_port   = -1
      protocol    = "icmp"
      to_port     = -1
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "All egress is routed through TGW and Network Firewall"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = {
    Name = "${local.name_prefix}-${each.value.display}-test"
  }
}
resource "aws_iam_role" "spoke_test" {
  for_each = local.spokes

  name = "${local.name_prefix}-${each.value.display}-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each = local.spokes

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.spoke_test[each.key].name
}

resource "aws_iam_instance_profile" "spoke_test" {
  for_each = local.spokes

  name = "${local.name_prefix}-${each.value.display}-ssm"
  role = aws_iam_role.spoke_test[each.key].name
}

resource "aws_instance" "spoke_test" {
  for_each = local.spokes

  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.spoke_test[each.key].name
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.spoke_private["${each.key}-az1"].id
  vpc_security_group_ids      = [aws_security_group.spoke_test[each.key].id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  depends_on = [
    aws_route.spoke_default,
    aws_networkfirewall_logging_configuration.main,
  ]

  tags = {
    Name = "${local.name_prefix}-${each.value.display}-test"
  }
}
