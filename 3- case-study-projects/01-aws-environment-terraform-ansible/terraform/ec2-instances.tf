
# ==================================================
# EC2 INSTANCES
# Ubuntu Server 22.04 LTS
# Region: us-east-1
# ==================================================


# --------------------------------------------------
# 1. Tomcat Application Server
# --------------------------------------------------

resource "aws_instance" "tomcat" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.app_security_group_01.id]
  iam_instance_profile        = aws_iam_instance_profile.my_ec2_ssm_instance_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "ec2-tomcat-01"
    Role = "Tomcat"
  }
}


# --------------------------------------------------
# 2. MariaDB Database Server
# --------------------------------------------------

resource "aws_instance" "mariadb" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.mariadb_security_group.id]
  iam_instance_profile        = aws_iam_instance_profile.my_ec2_ssm_instance_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "ec2-mariadb-01"
    Role = "MariaDB"
  }
}


# --------------------------------------------------
# 3. RabbitMQ Message Broker Server
# --------------------------------------------------

resource "aws_instance" "rabbitmq" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.rabbitmq_security_group.id]
  iam_instance_profile        = aws_iam_instance_profile.my_ec2_ssm_instance_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "ec2-rabbitmq-01"
    Role = "RabbitMQ"
  }
}


# --------------------------------------------------
# 4. Memcached Cache Server
# --------------------------------------------------

resource "aws_instance" "memcached" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.memcached_security_group.id]
  iam_instance_profile        = aws_iam_instance_profile.my_ec2_ssm_instance_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "ec2-memcached-01"
    Role = "Memcached"
  }
}


# ==================================================
# OUTPUTS
# ==================================================

output "tomcat_instance_id" {
  value = aws_instance.tomcat.id
}

output "tomcat_private_ip" {
  value = aws_instance.tomcat.private_ip
}

output "mariadb_instance_id" {
  value = aws_instance.mariadb.id
}

output "mariadb_private_ip" {
  value = aws_instance.mariadb.private_ip
}

output "rabbitmq_instance_id" {
  value = aws_instance.rabbitmq.id
}

output "rabbitmq_private_ip" {
  value = aws_instance.rabbitmq.private_ip
}

output "memcached_instance_id" {
  value = aws_instance.memcached.id
}

output "memcached_private_ip" {
  value = aws_instance.memcached.private_ip
}
