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

  availability_zone = "us-east-1a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "management-subnet" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.demo-vpc.id

  availability_zone = "us-east-1a"

  tags = {
    Name = "management-subnet"
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

resource "aws_network_interface" "primary-network-interface" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.1.100"]
  security_groups = [aws_security_group.allow-http.id]

  tags = {
    Name = "primary-network-interface"
  }
}

resource "aws_network_interface" "secondary-network-interface" {
  subnet_id       = aws_subnet.management-subnet.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.allow-ssh.id]

  tags = {
    Name = "allow-ssh"
  }
}

resource "aws_security_group" "allow-http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.demo-vpc.id

  tags = {
    Name = "allow-http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow-http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_http" {
  security_group_id = aws_security_group.allow-http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

}

resource "aws_security_group" "allow-ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic from the private subnet"
  vpc_id      = aws_vpc.demo-vpc.id

  tags = {
    Name = "allow-ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow-http.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
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

  network_interface {
    network_interface_id = aws_network_interface.secondary-network-interface.id
    device_index         = 1
  }

  user_data = filebase64("scripts/user_data.sh")

  tags = {
    Name = "my-server"
  }
}

resource "aws_eip" "eip" {
  network_interface = aws_network_interface.primary-network-interface.id
  vpc               = true
  depends_on        = [aws_instance.my-server]
}