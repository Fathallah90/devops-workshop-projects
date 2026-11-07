resource "aws_key_pair" "my_key_pair" {
  key_name   = "fathallah_key"
  public_key = file(pathexpand(var.fathallah_public_key_path))

  tags = {
    Name = "fathallah_key"
  }
}