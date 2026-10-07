aws_region   = "us-east-1"
project_name = "cloud-tf"
environment  = "dev"

vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
allowed_ssh_cidr   = "203.0.113.25/32" # replace with <your-public-ip>/32

# ami-760aaa0f is an Amazon Linux AMI that LocalStack ships in its mock image
# catalogue. For real AWS use a current Amazon Linux 2023 AMI for your region
# (see README -> "Running against real AWS").
ami_id        = "ami-760aaa0f"
instance_type = "t3.micro"

bucket_name = "tanish-cloud-tf-artifacts-2026"

# No AWS account credentials are configured on this machine, so the project is
# applied against LocalStack. Set to false to deploy to a real AWS account.
use_localstack = true
