terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

   backend "s3" {
    bucket         = "my-terraform-state-bucket-faheem"
    key            = "vote-app/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks-faheem"
    encrypt        = true
  }

}

provider "aws" {
  region = var.region
}

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vote-vpc-${var.signature}"
  }
}

############################
# Subnets
############################

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "public-subnet-${var.signature}"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "private-subnet-${var.signature}"
  }
}

############################
# Internet Gateway
############################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}


############################
# Route Tables
############################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}


resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

############################
# Security Groups
############################

# Vote/Result SG 
resource "aws_security_group" "faheem-vote-result-sg" {
  name   = "faheem-vote-result-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Change to your IP for security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

# Redis/Worker SG
resource "aws_security_group" "faheme-redis-worker-sf" {
  name   = "faheme-redis-worker-sf"
  vpc_id = aws_vpc.main.id

  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.faheem-vote-result-sg.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.faheem-vote-result-sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Postgres SG
resource "aws_security_group" "faheme-postgres-sf" {
  name   = "faheme-postgres-sf"
  vpc_id = aws_vpc.main.id

  
  ingress {
    from_port       = 5432 
    to_port         = 5432 
    protocol        = "tcp"
    security_groups = [aws_security_group.faheme-redis-worker-sf.id,aws_security_group.faheem-vote-result-sg.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.faheem-vote-result-sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# EC2 Instances
############################

# Instance A — (Vote + Result)
resource "aws_instance" "frontend" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.faheem-vote-result-sg.id]
  key_name               = var.key_name

  tags = {
    Name = "instance-a-frontend-(Vote + Result)-${var.signature}"
  }
}

# Instance B — (Redis + Worker)
resource "aws_instance" "backend" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.faheme-redis-worker-sf.id]
  key_name               = var.key_name

  tags = {
    Name = "instance-b-backend-(Redis + Worker)-${var.signature}"
  }
}

# Instance C — (PostgreSQL)
resource "aws_instance" "database" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.faheme-postgres-sf.id]
  key_name               = var.key_name

  tags = {
    Name = "instance-c-database-(PostgreSQL)-${var.signature}"
  }
}

############################
# Outputs for Ansible
############################

output "bastion_public_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "database_private_ip" {
  value = aws_instance.database.private_ip
}