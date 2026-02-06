variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "ami" {
  description = "ami"
  type        = string
  default     = "ami-0a854fe96e0b45e4e"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"
}


variable "key_name" {
  description = "key name"
  type        = string
  default     = "faheem-key-frankfurt"
}

variable "signature" {
  description = "My Signature"
  type        = string
  default     = "faheem"
}