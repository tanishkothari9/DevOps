# Terraform & Infrastructure as Code - Session 18 Homework

Homework for Session 18 has two parts: a hands-on Terraform project that manages an S3 bucket through the full Terraform workflow, and
research notes on five core AWS services.

## Deliverables

```text
Terraform-IaC/
|-- terraform-s3-demo/          # Task 1 - Terraform S3 demo
|   |-- main.tf
|   |-- variables.tf
|   |-- outputs.tf
|   |-- provider.tf
|   |-- terraform.tfvars
|   |-- README.md               # full workflow: commands, real outputs, screenshots
|   |-- outputs/                # raw output of every command
|   `-- screenshots/            # terminal screenshots
`-- aws-services/               # Task 2 - AWS services research
    |-- 01-iam/README.md
    |-- 02-ec2/README.md
    |-- 03-s3/README.md
    |-- 04-vpc/README.md
    `-- 05-dynamodb-rds/README.md
```

## Task 1: Terraform S3 Demo

**[terraform-s3-demo/README.md](terraform-s3-demo/README.md)**

The project creates an S3 bucket (`tanish-terraform-s3-demo-2026`) with versioning, SSE-S3 (AES256) default encryption and a public
access block. It then runs the complete workflow, with a screenshot and the real output for each step:

| Step | Command | Result |
|---|---|---|
| 1 | `terraform init` | AWS provider v6.67.0 installed, lock file created |
| 2 | `terraform fmt` | Code is in canonical format |
| 3 | `terraform validate` | Configuration is valid |
| 4 | `terraform plan` | 4 to add, 0 to change, 0 to destroy |
| 5 | `terraform apply` | 4 resources added |
| 6 | `terraform show` | State inspected |
| 7 | `terraform output` | Bucket name / ARN / region / versioning printed |
| 8 | `aws s3 ...` | Bucket, versioning, encryption, public access block and tags verified independently |
| 9 | `terraform destroy` | 4 resources destroyed, bucket confirmed gone (404) |

> No AWS account credentials are configured on this machine, so the project ran against **LocalStack**, a local AWS emulator
> in Docker. A single variable (`use_localstack`) switches the same code to real AWS. The project README explains the details.

## Task 2: AWS Services Research

| # | Service | Category | Topics covered |
|---|---|---|---|
| 01 | [IAM](aws-services/01-iam/README.md) | Governance | What is IAM, users, groups, roles, policies, permissions, least privilege, best practices, use cases |
| 02 | [EC2](aws-services/02-ec2/README.md) | Compute | What is EC2, AMI, instance types, key pairs, security groups, EBS, public vs private IP, instance lifecycle, use cases |
| 03 | [S3](aws-services/03-s3/README.md) | Storage | What is S3, buckets, objects, storage classes, versioning, lifecycle policies, encryption, bucket policies, use cases |
| 04 | [VPC](aws-services/04-vpc/README.md) | Networking | What is VPC, CIDR, subnets, route tables, internet gateway, NAT gateway, security groups, network ACLs, public vs private subnet |
| 05 | [DynamoDB & RDS](aws-services/05-dynamodb-rds/README.md) | Databases | DynamoDB: NoSQL, tables, items, attributes, partition key, sort key, use cases. RDS: relational DB, engines, DB instances, security, backups, Multi-AZ, read replicas, use cases |

## Key Terraform concepts (summary)

| Concept | Meaning |
|---|---|
| Infrastructure as Code | Infrastructure is defined in version-controlled files, which makes it repeatable, reviewable and automatable |
| Provider | Plugin that translates resources into a platform's API calls (`hashicorp/aws`) |
| Resource | An infrastructure object managed by Terraform (`aws_s3_bucket.demo`) |
| Variable / tfvars | Inputs that keep values out of the code |
| Output | Values exposed after apply (`terraform output`) |
| State | `terraform.tfstate`, which maps code to real resources. It is kept out of git and belongs in a remote backend for teams |
| Plan / Apply / Destroy | Preview changes, make the changes, remove everything |

Session 19 builds on this with a full VPC + EC2 + S3 project: [`../Cloud-Terraform-Project/`](../Cloud-Terraform-Project/README.md).
