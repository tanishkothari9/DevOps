# S3 bucket for build artefacts (test/scan reports, Helm packages) - private, versioned, encrypted.
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name}-artifacts-${var.aws_region}"
  force_destroy = true # demo bucket: allow `terraform destroy` to empty it
  tags          = { Name = "${local.name}-artifacts" }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132 -- SSE-S3 (AES256) is sufficient for CI artefacts; a CMK adds cost without benefit here
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Skipped on LocalStack 3.8: its S3 API does not return the transition-default-minimum-object-size
# header, so the AWS provider's post-create consistency waiter never completes.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count  = var.use_localstack ? 0 : 1
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Optional ECR repositories (the pipeline uses GHCR; ECR is the AWS-native alternative).
resource "aws_ecr_repository" "app" {
  for_each = var.enable_ecr ? toset(["backend", "frontend"]) : toset([])

  name                 = "${var.project}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
