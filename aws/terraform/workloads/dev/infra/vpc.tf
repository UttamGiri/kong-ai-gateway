data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name     = "${var.cluster_name}-vpc"
    Pipeline = "github-actions"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Nodes live in this one subnet (demo). EKS still needs a second AZ subnet for
# control-plane ENIs — AWS will not create a cluster with a single subnet.
resource "aws_subnet" "nodes" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = local.az_a
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-nodes"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "control_plane" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = local.az_b
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-eks-eni"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.cluster_name}-public"
  }
}

resource "aws_route_table_association" "nodes" {
  subnet_id      = aws_subnet.nodes.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "control_plane" {
  subnet_id      = aws_subnet.control_plane.id
  route_table_id = aws_route_table.public.id
}
