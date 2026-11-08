### ALB Security Group
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-alb"
  }
}

##----------------------------------------------------------------------------##

### Main Tomcat Web Server Security Group
#-------------------------------------

resource "aws_security_group" "app_security_group_01" {
  name        = "app-sg-01"
  description = "Security group for Tomcat application server"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-app-01"
  }
}

# ### Backup Tomcat Web Server Security Group
# #-------------------------------------

# resource "aws_security_group" "Tomcat_security_group_02" {
#   name        = "tomcat-sg-02"
#   description = "Security group for Backup Tomcat web server"
#   vpc_id      = aws_vpc.my_vpc.id

#   ingress {
#     description     = "HTTP from ALB only"
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb.id]
#   }


#   egress {
#     description = "Allow outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "sg-tomcat-02"
#   }
# }

##----------------------------------------------------------------------------##

### Database Security Group
#-------------------------------------
# This allows your database to accept connections from the Tomcat server and other required sources.

resource "aws_security_group" "mariadb_security_group" {
  name        = "mariadb-sg"
  description = "Security group for MariaDB database server"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description     = "Allow MariaDB from Tomcat"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_security_group_01.id]
    #Instead of allowing traffic from an IP address, we're allowing traffic from network interfaces associated with the Tomcat Security Group.
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-mariadb"
  }
}

##----------------------------------------------------------------------------##

### RabbitMQ Host Security Group
#-------------------------------------
# This allows your RabbitMQ server to accept connections from the Tomcat server and other required sources.

resource "aws_security_group" "rabbitmq_security_group" {
  name        = "rabbitmq-sg"
  description = "Security group for RabbitMQ server"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description     = "Allow AMQP from Tomcat"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.app_security_group_01.id]
    #Instead of allowing traffic from an IP address, we're allowing traffic from network interfaces associated with the Tomcat Security Group.
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-rabbitmq"
  }
}

##----------------------------------------------------------------------------##

### Memcached Security Group
#-------------------------------------
# This allows your Memcached server to accept connections from the Tomcat server and other required sources.

resource "aws_security_group" "memcached_security_group" {
  name        = "memcached-sg"
  description = "Security group for Memcached server"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description     = "Allow Memcached from Tomcat"
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.app_security_group_01.id]
    #Instead of allowing traffic from an IP address, we're allowing traffic from network interfaces associated with the Tomcat Security Group.
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-memcached"
  }
}