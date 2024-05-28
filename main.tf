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


resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/my-key.pub")
}

resource "aws_security_group" "network-security-group" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.demo-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nsg-inbound-ssh"
  }
}

resource "aws_network_interface" "primary-network-interface" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.1.100"]
  security_groups = [aws_security_group.network-security-group.id]

  tags = {
    Name = "primary-network-interface"
  }
}

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "my-server" {
  ami           = data.aws_ami.this.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.primary-network-interface.id
    device_index         = 0
  }

  tags = {
    Name = "my-server"
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.my-server.id
  vpc      = true
}