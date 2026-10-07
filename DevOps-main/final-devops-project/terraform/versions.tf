terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state for the course demo. For a team, switch to a remote backend, e.g.:
  # backend "s3" {
  #   bucket       = "stockpilot-tfstate-<account-id>"
  #   key          = "final-project/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}
