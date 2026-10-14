#amzone linux
data "aws_ami" "Amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# create new vpc for project 1
resource "aws_vpc" "prjoect1_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name       = "multi_stack_vpc_yogesh"
    managed_by = "terraform"
    owner      = var.creator_name
  }
}
# create public subnet for VPC
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.prjoect1_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name       = "public_subnet_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }
}
#create private subnet for VPC
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.prjoect1_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name       = "private_subnet_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }
}
#create internet gateway IG
resource "aws_internet_gateway" "project1_igw" {
  vpc_id = aws_vpc.prjoect1_vpc.id
  tags = {
    Name       = "igw_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }
}
# create eip for nat
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-gateway-eip"
  }

}
# creat nat to access internet gateway
resource "aws_nat_gateway" "project_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name       = "nat_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }
  # ensure internet gateway is created first
  depends_on = [aws_internet_gateway.project1_igw]
}
# create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prjoect1_vpc.id
   tags = {
    Name = "Route table for public subnet - Yogesh "
  }

}
#create internet acces to route public sunbet
resource "aws_route" "project_route_public" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project1_igw.id

}
# associate rt to public
resource "aws_route_table_association" "project1_rta_public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# create route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.prjoect1_vpc.id
  tags = {
    Name = "Route table for private subnet - Yogesh "
  }
}
#create internet acces to route private sunbet
resource "aws_route" "project_route_private" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.project_nat.id
 
}
# associate rt to public
resource "aws_route_table_association" "project1_rta_private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}
# Vote/Result SG: Allows incoming HTTP/HTTPS from the internet.
resource "aws_security_group" "vote_result_sg" {
  name        = "vote_result_sg_${var.creator_name}"
  description = "Security group for Vote and Result App"
  vpc_id      = aws_vpc.prjoect1_vpc.id
  tags = {
     Name       = "frontend_security_group_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }
}
# create security group ingress rule for ssh  for vote and result   
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_vote_result" {
  security_group_id = aws_security_group.vote_result_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

}
#create security group ingress for http
resource "aws_vpc_security_group_ingress_rule" "allow_htttp_vote_result" {
  security_group_id = aws_security_group.vote_result_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
#create security group ingress for http port 81
resource "aws_vpc_security_group_ingress_rule" "allow_htttp_vote_result_port81" {
  security_group_id = aws_security_group.vote_result_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 81
  to_port           = 81
  ip_protocol       = "tcp"
}
#create security group ingress for http
resource "aws_vpc_security_group_ingress_rule" "allow_htttp_vote_result_port82" {
  security_group_id = aws_security_group.vote_result_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 82
  to_port           = 82
  ip_protocol       = "tcp"
}
#create security group rule for outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_outbound_all_result" {
  security_group_id = aws_security_group.vote_result_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#Backend : Redis/Worker SG: Allows inbound traffic from redis worker EC2 (6379), and allows outbound to Postgres.
resource "aws_security_group" "redis_worker_sg" {
  name        = "redis_worker_${var.creator_name}"
  description = "Security group for redis and worker App Backend"
  vpc_id      = aws_vpc.prjoect1_vpc.id
   tags = {
     Name       = "backend_security_group_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }

}
# create security group ingress rule for ssh  redis and worker
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_redis_worker" {
  security_group_id = aws_security_group.redis_worker_sg.id
  referenced_security_group_id  = "92.209.188.231/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

}

#Allows inbound traffic from Vote/Result EC2 to Redis port (6379)
resource "aws_vpc_security_group_ingress_rule" "allow_htttp_redis" {
  security_group_id = aws_security_group.redis_worker_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"

}
#create security group rule for outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_outbound_redis" {
  security_group_id = aws_security_group.redis_worker_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}
#Allows inbound traffic to postgress from backedn worker 
resource "aws_vpc_security_group_egress_rule" "allow_htttp_backend" {
  security_group_id = aws_security_group.postgres_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# database Postgres SG: Allows inbound traffic on port 5432 only from the Worker SG (and possibly from Vote/Result if needed directly).
resource "aws_security_group" "postgres_sg" {
  name        = "postgres_${var.creator_name}"
  description = "Security group for database"
  vpc_id      = aws_vpc.prjoect1_vpc.id
   tags = {
     Name       = "database_security_group_${var.creator_name}"
    owner      = var.creator_name
    managed_by = "terraform"
  }

}
# create security group ingress rule for ssh  Postgress  
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_postgress_db" {
  security_group_id = aws_security_group.postgres_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

}
#Allows inbound traffic from postgress to worker SG (5432)
resource "aws_vpc_security_group_ingress_rule" "allow_port_5432" {
  security_group_id = aws_security_group.postgres_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}
#Allows inbound traffic to postgress from postgress worker 
resource "aws_vpc_security_group_egress_rule" "allow_htttp_postgress" {
  security_group_id = aws_security_group.postgres_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
#create security group rule for outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_outbound_all_postgress" {
  security_group_id = aws_security_group.postgres_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#generate keys
resource "tls_private_key" "yogesh_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "yogesh_ssh_key" {
  key_name   = "${var.creator_name}_ssh_key"
  public_key = tls_private_key.yogesh_ssh_key.public_key_openssh
}
#save private key to local file
resource "local_file" "yogesh_private_key" {
  content         = tls_private_key.yogesh_ssh_key.private_key_pem
  filename        = "${path.module}/../ansible/yogesh_ssh_key.pem"
  file_permission = "0600"
}

# create EC2 instance 1 in a public subnet from Vote + Result
resource "aws_instance" "ec2_vote_result" {
  ami                         = data.aws_ami.Amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.yogesh_ssh_key.id
  vpc_security_group_ids      = [aws_security_group.vote_result_sg.id]
  tags = {
    Name       = "ec2_vote_result_${var.creator_name}_frontend"
    managed_by = "terraform"
    owner      = var.creator_name
  }
}
# create EC2 instance 2 in a private subnet for Redis + Worker
resource "aws_instance" "ec2_redis_worker" {
  ami                         = data.aws_ami.Amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_subnet.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.yogesh_ssh_key.id
  vpc_security_group_ids      = [aws_security_group.redis_worker_sg.id]
  tags = {
    Name       = "ec2_redis_worker_${var.creator_name}_backend"
    managed_by = "terraform"
    owner      = var.creator_name
  }
}
# create EC2 instance 3 in a private subnet for PostgreSQL
resource "aws_instance" "ec2_postgres_db" {
  ami                         = data.aws_ami.Amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_subnet.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.yogesh_ssh_key.id
  vpc_security_group_ids      = [aws_security_group.postgres_sg.id]
  tags = {
    Name       = "ec2_Postgres_db_${var.creator_name}_database"
    managed_by = "terraform"
    owner      = var.creator_name
  }
}

# # # Generate the Ansible inventory directly from the instance
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = <<EOF

[frontend] 
ansible_host=${aws_instance.ec2_vote_result.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${var.creator_name}_ssh_key.pem

[backend]
ansible_host=${aws_instance.ec2_redis_worker.private_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${var.creator_name}_ssh_key.pem

[database]
ansible_host=${aws_instance.ec2_postgres_db.private_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${var.creator_name}_ssh_key.pem

EOF
}