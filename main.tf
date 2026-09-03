terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. AWS Provider
provider "aws" {
  region = "us-east-1"
}

# 2. Dynamic AMI Lookup (Amazon Linux 2023)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 3. Security Group for App Server
resource "aws_security_group" "app_sg" {
  name        = "simple-java-app-sg"
  description = "Allow HTTP, App Port, and SSH traffic"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard HTTP Port 80
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Java App Port 8080
  ingress {
    description = "App Port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic allowed
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "simple-java-app-sg"
  }
}

# 4. EC2 Instance with Docker Pre-installed
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = "jenkins-key" # Aapka EC2 key-pair name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # User data: Docker auto-install on launch
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              EOF

  tags = {
    Name = "simple-java-app-server"
  }
}

# 5. Output Server Public IP
output "app_server_public_ip" {
  description = "Public IP of the deployed app server"
  value       = aws_instance.app_server.public_ip
}
