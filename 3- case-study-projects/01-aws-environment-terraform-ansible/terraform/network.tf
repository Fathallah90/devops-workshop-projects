resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "devops-workshop-igw"
  }
}


## Public Subnets
#-------------------------------

## Public Subnet in us-east-1a Availability Zone
resource "aws_subnet" "my_public_subnet_us-east-1a" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_cidr_us-east-1a
  availability_zone       = var.availability_zone_us-east-1a
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${var.availability_zone_us-east-1a}"
  }
}

## Public Subnet in us-east-1b Availability Zone
resource "aws_subnet" "my_public_subnet_us-east-1b" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_cidr_us-east-1b
  availability_zone       = var.availability_zone_us-east-1b
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${var.availability_zone_us-east-1b}"
  }
}

## Public Subnet in us-east-1a Availability Zone Route Table
resource "aws_route_table" "my_public_route_table_us-east-1a" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "public_subnet_route_table_us-east-1a"
  }
}

## Public Subnet in us-east-1b Availability Zone Route Table
resource "aws_route_table" "my_public_route_table_us-east-1b" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "public_subnet_route_table_us-east-1b"
  }
}

## Public Subnet in us-east-1a Availability Zone Route to Internet Gateway
resource "aws_route" "public_internet_us-east-1a" {
  route_table_id         = aws_route_table.my_public_route_table_us-east-1a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

## Public Subnet in us-east-1b Availability Zone Route to Internet Gateway
resource "aws_route" "public_internet_us-east-1b" {
  route_table_id         = aws_route_table.my_public_route_table_us-east-1b.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

## Public Subnet in us-east-1a Availability Zone Route Table Association
resource "aws_route_table_association" "my_public_subnet_association_us-east-1a" {
  subnet_id      = aws_subnet.my_public_subnet_us-east-1a.id
  route_table_id = aws_route_table.my_public_route_table_us-east-1a.id
}

## Public Subnet in us-east-1b Availability Zone Route Table Association
resource "aws_route_table_association" "my_public_subnet_association_us-east-1b" {
  subnet_id      = aws_subnet.my_public_subnet_us-east-1b.id
  route_table_id = aws_route_table.my_public_route_table_us-east-1b.id
}
##---------------------------------------------------------------------------##

## Private Subnets
#-------------------------------
resource "aws_subnet" "my_private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.private_data_subnet_cidr
  availability_zone       = var.availability_zone_us-east-1a
  map_public_ip_on_launch = false
  #Assign Public IP Automatically to instances launched in this subnet. Set to false for private subnets.

  tags = {
    Name = "subnet-private-${var.availability_zone_us-east-1a}"
  }
}

##---------------------------------------------------------------------------##

## Private Subnet Route Table
resource "aws_route_table" "my_private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private_subnet_route_table"
  }
}

# Uncomment the following block to create a route in the private route table that directs traffic to the NAT Gateway for internet access.
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.my_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

## Private Subnet Route Table Association
resource "aws_route_table_association" "my_private_subnet_association" {
  subnet_id      = aws_subnet.my_private_subnet.id
  route_table_id = aws_route_table.my_private_route_table.id
}

##---------------------------------------------------------------------------##

## Create an Elastic IP for the NAT Gateway
resource "aws_eip" "Elastic_IP_NAT" {
  domain = "vpc"

  tags = {
    Name = "eip-nat-devops"
  }
}

### Create a NAT Gateway in the public subnet
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.Elastic_IP_NAT.id
  subnet_id     = aws_subnet.my_public_subnet_us-east-1a.id

  connectivity_type = "public"

  tags = {
    Name = "nat-gateway-devops"
  }

  depends_on = [
    aws_internet_gateway.my_igw
  ]
}