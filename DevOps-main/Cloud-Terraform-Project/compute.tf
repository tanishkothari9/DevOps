# EC2 web server in the public subnet.
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id        # implicit dependency
  vpc_security_group_ids = [aws_security_group.web.id] # implicit dependency

  # Installs nginx on first boot and writes a page that names the S3 bucket
  # (referencing the bucket is another implicit dependency).
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>${var.project_name} web server</h1><p>Artifacts bucket: ${aws_s3_bucket.artifacts.bucket}</p>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # Explicit dependency: nothing above references the Internet Gateway or the
  # route table association, but the user_data script needs internet access
  # (dnf install) the moment the instance boots, so the public route must
  # exist before the instance is created.
  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public,
  ]

  tags = {
    Name = "${var.project_name}-web"
  }
}
