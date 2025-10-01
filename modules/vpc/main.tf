resource "aws_vpc" "network" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true
  tags                             = var.global_tags
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.network.id
  tags   = var.global_tags
}

# resource "aws_route_table" "default" {
#   vpc_id = aws_vpc.network.id
#   tags   = var.global_tags

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.gateway.id
#   }
# }


resource "aws_route_table" "default" {
  vpc_id = aws_vpc.network.id
  tags   = var.global_tags
}

resource "aws_route" "internet_gateway_route" {
  route_table_id         = aws_route_table.default.id
  gateway_id             = aws_internet_gateway.gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.network.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  tags                    = var.global_tags
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.default.id
  subnet_id      = aws_subnet.public.id
}
