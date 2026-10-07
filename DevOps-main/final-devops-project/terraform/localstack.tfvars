# Run against LocalStack community (docker run -d --name localstack -p 4566:4566 localstack/localstack:3.8).
# No AWS account or credentials needed; the provider uses dummy "test" keys and the edge endpoint below.
use_localstack      = true
localstack_endpoint = "http://localhost:4566"
environment         = "dev"

# EKS and ECR are LocalStack Pro features -> use the single-node k3s host as the Kubernetes substitute.
enable_eks      = false
enable_ecr      = false
enable_k3s_node = true
ami_id          = "ami-1e749f67" # LocalStack mock Ubuntu AMI
