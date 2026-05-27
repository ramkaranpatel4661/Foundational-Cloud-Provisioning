# ---------------------------------------------------------------------------
# Cloud Provisioning Task — Terraform Configuration
# Author: Ramkaran Patel
# Region: ap-south-1 (Mumbai) — using Mumbai because that's the closest
#         region for low-latency testing from India.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "ap-south-1"
}


# ---------------------------------------------------------------------------
# Data Source: Fetch the latest Ubuntu 22.04 LTS AMI dynamically.
# Hardcoding AMI IDs is a footgun — they're region-specific and go stale.
# This block always resolves to the current canonical image so we never
# have to touch it again.
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}


# ---------------------------------------------------------------------------
# Networking — VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "dev_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # needed so the instance gets a public DNS name

  tags = {
    Name    = "dev-vpc"
    Project = "Cloud-Provisioning-Task"
  }
}


# ---------------------------------------------------------------------------
# Networking — Public Subnet
# Note: map_public_ip_on_launch = true is important here. Without it, the
# EC2 instance won't automatically receive a public IP at launch and we'd
# have to deal with Elastic IPs, which is overkill for this setup.
# ---------------------------------------------------------------------------
resource "aws_subnet" "dev_public_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "dev-public-subnet"
    Project = "Cloud-Provisioning-Task"
  }
}


# ---------------------------------------------------------------------------
# Networking — Internet Gateway
# The VPC is isolated by default. Attaching an IGW is what actually makes
# traffic flow in and out of the public subnet.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name    = "dev-igw"
    Project = "Cloud-Provisioning-Task"
  }
}


# ---------------------------------------------------------------------------
# Networking — Route Table
# We need an explicit route sending all non-local traffic (0.0.0.0/0)
# through the IGW. AWS's default route table doesn't have this.
# ---------------------------------------------------------------------------
resource "aws_route_table" "dev_public_rt" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  tags = {
    Name    = "dev-public-rt"
    Project = "Cloud-Provisioning-Task"
  }
}

# Associate the route table with the public subnet so it actually takes effect.
resource "aws_route_table_association" "dev_public_rta" {
  subnet_id      = aws_subnet.dev_public_subnet.id
  route_table_id = aws_route_table.dev_public_rt.id
}


# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------
resource "aws_security_group" "dev_sg" {
  name        = "dev-server-sg"
  description = "Allow inbound SSH and HTTP traffic for the dev server"
  vpc_id      = aws_vpc.dev_vpc.id

  # Note: Opening SSH to 0.0.0.0/0 is bad practice for production, but
  # necessary here for the assignment requirements. In a real environment
  # this would be locked down to a specific bastion IP or VPN CIDR.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic — the instance needs to reach the internet
  # to pull packages, updates, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "dev-server-sg"
    Project = "Cloud-Provisioning-Task"
  }
}


# ---------------------------------------------------------------------------
# Compute — EC2 Instance
# ---------------------------------------------------------------------------
resource "aws_instance" "dev_server" {
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.dev_public_subnet.id
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  # If you have a key pair already set up in ap-south-1, uncomment this.
  # key_name = "your-key-pair-name"

  root_block_device {
    volume_size           = 8    # GB — default is fine for a dev box
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "dev-server"
    Project = "Cloud-Provisioning-Task"
  }
}


# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "server_public_ip" {
  description = "Public IP of the dev EC2 instance — use this to SSH in."
  value       = aws_instance.dev_server.public_ip
}
