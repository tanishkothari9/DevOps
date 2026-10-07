# Low-cost / LocalStack-friendly Kubernetes host: one EC2 instance that installs k3s on boot.
data "aws_ami" "ubuntu" {
  count       = var.enable_k3s_node && var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s" {
  count = var.enable_k3s_node ? 1 : 0

  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.node_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ingress.id, aws_security_group.nodes.id]
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/templates/k3s-user-data.sh.tftpl", {
    k3s_version = "v1.33.4+k3s1"
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = { Name = "${local.name}-k3s", Role = "kubernetes-node" }
}
