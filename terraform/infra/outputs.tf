output "frontend_private_ip" {
  description = "A: private IP"
  value       = aws_instance.frontend.private_ip
}

output "backend_private_ip" {
  description = "B: private IP (REDIS_HOST for Vote)"
  value       = aws_instance.backend.private_ip
}

output "db_private_ip" {
  description = "C: private IP (DB_HOST / PG_HOST)"
  value       = aws_instance.db.private_ip
}

output "bastion_public_ip" {
  description = "Bastion: public IP (SSH jump host)"
  value       = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  description = "ALB address: http://<this>/vote and http://<this>/result"
  value       = aws_lb.main.dns_name
}