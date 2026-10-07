# One provider block for both targets:
#   use_localstack = true  -> every API call goes to LocalStack (dummy credentials, no AWS account needed)
#   use_localstack = false -> normal AWS credential chain (env vars / ~/.aws / SSO), real resources and real cost
provider "aws" {
  region = var.aws_region

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
      ecr = endpoints.value
      eks = endpoints.value
      iam = endpoints.value
      kms = endpoints.value
      s3  = endpoints.value
      sts = endpoints.value
    }
  }

  default_tags {
    tags = local.common_tags
  }
}
