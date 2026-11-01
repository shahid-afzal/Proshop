terraform {
  backend "s3" {
    bucket         = "proshop-state-494949" 
    key            = "global/s3/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    }
}

provider "aws" {
    region = "ap-south-1"
}

resource "aws_key_pair" "deployer" {
    key_name   = "deployer-key"
    public_key = file("~/.ssh/github_actions.pub")
}

resource "aws_security_group" "web_sg" {
    ingress {
        from_port =22
        to_port =22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    ingress {
        description = "HTTP traffic"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # This is Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "proshop_server" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.web_sg.id]
}

output "server_public_ip" {
  description = "The public IP address of our new EC2 server"
  value       = aws_instance.proshop_server.public_ip
}

resource "aws_security_group" "db_sg" {
  ingress {
    description     = "MongoDB Internal Traffic"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "db_server" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.db_sg.id]

    #This script installs Docker and runs MongoDB automatically
    user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo docker run -d -p 27017:27017 --name mongo --restart always mongo
              EOF
}

output "db_private_ip" {
    description = " The internal IP address of our database server"
    value = aws_instance.db_server.private_ip
}