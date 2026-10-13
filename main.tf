resource "aws_instance" "first" {
  #checkov:skip=CKV2_AWS_41:Demo instance does not call any AWS APIs, so no IAM role is needed
  ami                    = lookup(var.ami_id, var.region)
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.training.id]
  user_data              = file("./install.sh")
  monitoring             = true
  ebs_optimized          = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "sathishbabu"
  }
}
