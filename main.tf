provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.demo-vpc.id

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.demo-vpc.id

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "demo-vpc-igw" {
  vpc_id = aws_vpc.demo-vpc.id

  tags = {
    Name = "demo-vpc-igw"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-vpc-igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "route-table-assoc" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-route-table.id
}

