# ---------- General ----------
variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used in resource names and tags."
  type        = string
  default     = "cloud-tf"
}

variable "environment" {
  description = "Environment name (dev / staging / prod)."
  type        = string
  default     = "dev"
}

# ---------- Networking ----------
variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet (must sit inside vpc_cidr)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone_suffix" {
  description = "AZ letter for the subnet; combined with the region, e.g. us-east-1 + a."
  type        = string
  default     = "a"
}

variable "allowed_ssh_cidr" {
  description = "Only this CIDR may SSH (port 22) into the instance. Use your own public IP/32."
  type        = string
}

# ---------- Compute ----------
variable "ami_id" {
  description = "AMI ID for the EC2 instance (region specific)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH. null = no key pair attached."
  type        = string
  default     = null
}

# ---------- Storage ----------
variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

# ---------- LocalStack ----------
variable "use_localstack" {
  description = "Send AWS API calls to LocalStack (local AWS emulator) instead of real AWS."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint, only used when use_localstack = true."
  type        = string
  default     = "http://localhost:4566"
}
