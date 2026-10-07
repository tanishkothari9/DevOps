terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The AWS provider.
#
# When use_localstack = true (the default in terraform.tfvars) every AWS API call
# is sent to LocalStack, a local AWS emulator running in Docker on port 4566,
# with dummy credentials. When use_localstack = false all of the overrides below
# switch off and the provider behaves exactly like a normal AWS provider, picking
# up real credentials from `aws configure` / environment variables.
provider "aws" {
  region = var.aws_region

  # ---- LocalStack overrides (all disabled when use_localstack = false) ----
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [var.localstack_endpoint] : []
    content {
      s3  = endpoints.value
      iam = endpoints.value
      sts = endpoints.value
      ec2 = endpoints.value
    }
  }
  # -------------------------------------------------------------------------

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "Session18-terraform-s3-demo"
    }
  }
}
