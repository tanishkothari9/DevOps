variable "aws_region" {
  description = "AWS region for every resource."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix for resource names."
  type        = string
  default     = "stockpilot"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "use_localstack" {
  description = "Send all AWS API calls to LocalStack instead of a real AWS account."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint (only used when use_localstack = true)."
  type        = string
  default     = "http://localhost:4566"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnets (one per AZ): ingress / load balancers / NAT."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnets (two AZs) are required."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnets (one per AZ): Kubernetes worker nodes."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway so private subnets can reach the internet (costs money on AWS)."
  type        = bool
  default     = true
}

variable "ingress_cidrs" {
  description = "CIDRs allowed to reach the public HTTP/HTTPS ingress."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API of the single-node cluster / EKS public endpoint."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "enable_eks" {
  description = "Create an EKS control plane + managed node group (real AWS only: EKS is not in LocalStack community)."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "Instance type for EKS worker nodes and the single-node k3s host."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "enable_k3s_node" {
  description = "Create a single EC2 host running k3s - a low-cost substitute for EKS (works on LocalStack)."
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "AMI for the k3s host. Empty = latest Ubuntu 24.04 LTS from Canonical."
  type        = string
  default     = ""
}

variable "enable_ecr" {
  description = "Create ECR repositories (alternative to GHCR; not available in LocalStack community)."
  type        = bool
  default     = true
}
