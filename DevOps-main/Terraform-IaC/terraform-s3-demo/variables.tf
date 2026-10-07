variable "aws_region" {
  description = "AWS region where the S3 bucket will be created."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique name of the S3 bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket names must be 3-63 chars of lowercase letters, numbers, dots and hyphens."
  }
}

variable "environment" {
  description = "Environment tag applied to the bucket."
  type        = string
  default     = "dev"
}

variable "enable_versioning" {
  description = "Turn on S3 object versioning for the bucket."
  type        = bool
  default     = true
}

variable "use_localstack" {
  description = "Send AWS API calls to LocalStack (local AWS emulator) instead of real AWS."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "URL of the LocalStack edge endpoint (only used when use_localstack = true)."
  type        = string
  default     = "http://localhost:4566"
}
