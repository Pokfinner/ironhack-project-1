output "db_private_ip" {
    value = aws_instance.ec2_postgres_db.private_ip
}
output "backend_private_ip"{
    value = aws_instance.ec2_redis_worker.private_ip
}
output "vote_result_private"{
    value = aws_instance.ec2_vote_result.private_ip
}