# S3 bucket for application artifacts.
resource "aws_s3_bucket" "artifacts" {
  bucket        = var.bucket_name
  force_destroy = true # allow `terraform destroy` even when the bucket holds objects

  tags = {
    Name = var.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A small object describing the deployment. It references the EC2 instance and
# VPC IDs, so Terraform creates it only after those exist (implicit dependency).
resource "aws_s3_object" "deployment_info" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "deployment/info.json"
  content_type = "application/json"
  content = jsonencode({
    project     = var.project_name
    environment = var.environment
    vpc_id      = aws_vpc.main.id
    subnet_id   = aws_subnet.public.id
    instance_id = aws_instance.web.id
  })
}
