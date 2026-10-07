aws_region        = "us-east-1"
bucket_name       = "tanish-terraform-s3-demo-2026"
environment       = "dev"
enable_versioning = true

# No AWS account credentials are configured on this machine, so the demo runs
# against LocalStack (local AWS emulator). Set this to false to deploy to real AWS.
use_localstack = true
