variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS VPC"
  type        = string
}

variable "availability_zone_us-east-1a" {
  description = "AWS Availability Zone"
  type        = string
}

variable "availability_zone_us-east-1b" {
  description = "us-east-2 AWS Availability Zone"
  type        = string
}

variable "public_subnet_cidr_us-east-1a" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "public_subnet_cidr_us-east-1b" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "private_data_subnet_cidr" {
  description = "CIDR block for the private data subnet"
  type        = string
}

variable "fathallah_public_key_path" {
  description = "Path to the SSH public key on the local machine"
  type        = string
}

variable "EC2_instance_type" {
  description = "EC2 instance type for the NGINX server"
  type        = string
  default     = "t3.micro"
}