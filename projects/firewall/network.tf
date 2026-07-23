resource "aws_vpc" "inspection" {
  cidr_block           = var.inspection_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-inspection-vpc"
  }
}

resource "aws_internet_gateway" "inspection" {
  vpc_id = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-inspection-igw"
  }
}

resource "aws_subnet" "inspection_tgw" {
  for_each = local.azs

  availability_zone       = each.value.name
  cidr_block              = cidrsubnet(var.inspection_vpc_cidr, 8, each.value.index)
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-tgw-${each.key}"
    Tier = "TransitGateway"
  }
}

resource "aws_subnet" "inspection_firewall" {
  for_each = local.azs

  availability_zone       = each.value.name
  cidr_block              = cidrsubnet(var.inspection_vpc_cidr, 8, each.value.index + 10)
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-firewall-${each.key}"
    Tier = "NetworkFirewall"
  }
}

resource "aws_subnet" "inspection_public" {
  for_each = local.azs

  availability_zone       = each.value.name
  cidr_block              = cidrsubnet(var.inspection_vpc_cidr, 8, each.value.index + 20)
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "NATGateway"
  }
}

resource "aws_eip" "nat" {
  for_each = local.azs

  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "main" {
  for_each = local.azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.inspection_public[each.key].id

  depends_on = [aws_internet_gateway.inspection]

  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }
}

resource "aws_route_table" "inspection_tgw" {
  for_each = local.azs

  vpc_id = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-tgw-routes-${each.key}"
  }
}

resource "aws_route" "inspection_tgw_default" {
  for_each = local.azs

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.inspection_tgw[each.key].id
  vpc_endpoint_id        = local.firewall_endpoints[each.value.name]
}

resource "aws_route_table_association" "inspection_tgw" {
  for_each = local.azs

  route_table_id = aws_route_table.inspection_tgw[each.key].id
  subnet_id      = aws_subnet.inspection_tgw[each.key].id
}

resource "aws_route_table" "inspection_firewall" {
  for_each = local.azs

  vpc_id = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-firewall-routes-${each.key}"
  }
}

resource "aws_route" "inspection_firewall_default" {
  for_each = local.azs

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
  route_table_id         = aws_route_table.inspection_firewall[each.key].id
}

resource "aws_route" "inspection_firewall_to_spoke" {
  for_each = local.firewall_routes_to_spokes

  destination_cidr_block = each.value.cidr_block
  route_table_id         = aws_route_table.inspection_firewall[each.value.az_key].id
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.inspection,
    aws_ec2_transit_gateway_route.inspection_to_spoke,
  ]
}

resource "aws_route_table_association" "inspection_firewall" {
  for_each = local.azs

  route_table_id = aws_route_table.inspection_firewall[each.key].id
  subnet_id      = aws_subnet.inspection_firewall[each.key].id
}

resource "aws_route_table" "inspection_public" {
  for_each = local.azs

  vpc_id = aws_vpc.inspection.id

  tags = {
    Name = "${local.name_prefix}-public-routes-${each.key}"
  }
}

resource "aws_route" "inspection_public_default" {
  for_each = local.azs

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.inspection.id
  route_table_id         = aws_route_table.inspection_public[each.key].id
}

resource "aws_route" "inspection_public_to_spoke" {
  for_each = local.firewall_routes_to_spokes

  destination_cidr_block = each.value.cidr_block
  route_table_id         = aws_route_table.inspection_public[each.value.az_key].id
  vpc_endpoint_id        = local.firewall_endpoints[local.azs[each.value.az_key].name]
}

resource "aws_route_table_association" "inspection_public" {
  for_each = local.azs

  route_table_id = aws_route_table.inspection_public[each.key].id
  subnet_id      = aws_subnet.inspection_public[each.key].id
}

resource "aws_vpc" "spoke" {
  for_each = local.spokes

  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-${each.value.display}-vpc"
  }
}

resource "aws_subnet" "spoke_private" {
  for_each = local.spoke_subnets

  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.spoke[each.value.spoke_name].id

  tags = {
    Name = "${local.name_prefix}-${replace(each.value.spoke_name, "_", "-")}-${each.value.az_key}"
    Tier = "Private"
  }
}

resource "aws_route_table" "spoke_private" {
  for_each = local.spoke_subnets

  vpc_id = aws_vpc.spoke[each.value.spoke_name].id

  tags = {
    Name = "${local.name_prefix}-${replace(each.value.spoke_name, "_", "-")}-routes-${each.value.az_key}"
  }
}

resource "aws_route" "spoke_default" {
  for_each = local.spoke_subnets

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.spoke_private[each.key].id
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.spoke,
    aws_ec2_transit_gateway_route.spoke_default,
  ]
}

resource "aws_route_table_association" "spoke_private" {
  for_each = local.spoke_subnets

  route_table_id = aws_route_table.spoke_private[each.key].id
  subnet_id      = aws_subnet.spoke_private[each.key].id
}
