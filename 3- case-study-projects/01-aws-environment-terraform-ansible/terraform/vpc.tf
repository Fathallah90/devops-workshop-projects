resource "aws_vpc" "my_vpc" {

  cidr_block = var.vpc_cidr

  enable_dns_support = true
  #Enables DNS resolution through the Amazon-provided DNS resolver.
  enable_dns_hostnames = true
  #These settings are important for communication between AWS resources using DNS names.

  tags = {
    Name = "devops-workshop-vpc"
    # Environment = "Learning"
    # Project     = "AWS-OnPrem-Migration"
    # ManagedBy   = "Terraform"
  }
}