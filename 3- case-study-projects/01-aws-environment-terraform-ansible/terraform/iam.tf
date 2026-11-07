# Allow EC2 instances to assume this IAM role
resource "aws_iam_role" "my_ec2_ssm" {
  name = "devops-role-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "devops-role-ec2-ssm"
  }
}

# Grant the EC2 instance permission to use Systems Manager
resource "aws_iam_role_policy_attachment" "my_ec2_ssm_core" {
  role       = aws_iam_role.my_ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Make the IAM role available to EC2 instances
resource "aws_iam_instance_profile" "my_ec2_ssm_instance_profile" {
  name = "instance-profile-devops-ec2-ssm"
  role = aws_iam_role.my_ec2_ssm.name

  tags = {
    Name = "instance-profile-devops-ec2-ssm"
  }
}