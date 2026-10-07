# AWS provider.
#
# use_localstack = true  -> every API call goes to LocalStack (a local AWS emulator
#                           running in Docker on port 4566) with dummy credentials.
# use_localstack = false -> all overrides below switch off and the provider talks to
#                           real AWS using the credentials from `aws configure`,
#                           AWS_PROFILE or environment variables.
provider "aws" {
  region = var.aws_region

  # ---- LocalStack overrides (disabled when use_localstack = false) ----
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [var.localstack_endpoint] : []
    content {
      ec2 = endpoints.value
      s3  = endpoints.value
      iam = endpoints.value
      sts = endpoints.value
    }
  }
  # ---------------------------------------------------------------------

  # Tags added to every resource this provider creates.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Session     = "19"
    }
  }
}
