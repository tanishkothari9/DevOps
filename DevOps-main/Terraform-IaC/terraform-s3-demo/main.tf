# The S3 bucket itself.
resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets `terraform destroy` delete the bucket even if it holds objects

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Object versioning (keeps every version of an object).
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Default encryption at rest with S3-managed keys (SSE-S3 / AES-256).
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access to the bucket.
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
