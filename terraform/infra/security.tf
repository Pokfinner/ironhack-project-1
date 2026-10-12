# ---------- SG-A: Frontend (Vote + Result + bastion) ----------
resource "aws_security_group" "frontend" {
  name        = "hserindik-voting-app-frontend-sg"
  description = "Vote, Result and SSH (bastion)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Vote from the internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Result from the internet"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH only from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hserindik-voting-app-frontend-sg"
  }
}

# ---------- SG-B: Backend (Redis + Worker) ----------
resource "aws_security_group" "backend" {
  name        = "hserindik-voting-app-backend-sg"
  description = "Redis from frontend, SSH via bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from frontend (Vote)"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "SSH from bastion (frontend)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hserindik-voting-app-backend-sg"
  }
}

# ---------- SG-C: Database (PostgreSQL) ----------
resource "aws_security_group" "db" {
  name        = "hserindik-voting-app-db-sg"
  description = "PostgreSQL from frontend and backend, SSH via bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from frontend (Result) and backend (Worker)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.frontend.id,
      aws_security_group.backend.id
    ]
  }

  ingress {
    description     = "SSH from bastion (frontend)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hserindik-voting-app-db-sg"
  }
}