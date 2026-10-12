variable "my_ip" {
  description = "My public IP address for SSH access, in CIDR format (e.g. 1.2.3.4/32)"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID in us-east-1 (ubuntu-noble-24.04-amd64-server-20261004). Update consciously."
  type        = string
  default     = "ami-0fa5967347d08d2df"
}