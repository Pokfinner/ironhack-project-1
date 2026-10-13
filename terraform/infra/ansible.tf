# ---------- Generate Ansible files from Terraform outputs ----------

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory.ini"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    frontend_public_ip = aws_instance.frontend.public_ip
    backend_private_ip = aws_instance.backend.private_ip
    db_private_ip      = aws_instance.db.private_ip
  })
}

resource "local_file" "ansible_group_vars" {
  filename = "${path.module}/../../ansible/group_vars/all.yml"
  content = templatefile("${path.module}/templates/group_vars_all.tftpl", {
    backend_private_ip = aws_instance.backend.private_ip
    db_private_ip      = aws_instance.db.private_ip
  })
}