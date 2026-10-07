terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State is stored locally in terraform.tfstate (default "local" backend).
  # For a team setup, switch to a remote backend, e.g.:
  #
  # backend "s3" {
  #   bucket       = "my-terraform-state-bucket"
  #   key          = "cloud-terraform-project/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true # S3-native state locking
  # }
}
