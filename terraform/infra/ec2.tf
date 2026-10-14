# ---------- SSH key pair ----------
resource "aws_key_pair" "main" {
  key_name   = "hserindik-voting-app-key"
  public_key = file(pathexpand("~/.ssh/voting-app-key.pub"))
}

# ---------- A: Frontend (Vote + Result + bastion) ----------
resource "aws_instance" "frontend" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_frontend.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = aws_key_pair.main.key_name

  tags = {
    Name = "hserindik-voting-app-A-frontend"
  }
}

# ---------- B: Backend (Redis + Worker) ----------
resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = aws_key_pair.main.key_name

  tags = {
    Name = "hserindik-voting-app-B-backend"
  }
}

# ---------- C: Database (PostgreSQL) ----------
resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.main.key_name

  tags = {
    Name = "hserindik-voting-app-C-db"
  }
}

# ---------- Bastion (public subnet, SSH only) ----------
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.main.key_name

  tags = {
    Name = "hserindik-voting-app-bastion"
  }
}