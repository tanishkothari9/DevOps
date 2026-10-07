# S3 - Storage

Research notes on Amazon Simple Storage Service (S3): durable, virtually unlimited object storage accessed over HTTPS.

## What is S3?

Amazon S3 stores data as **objects** inside **buckets**. It is not a file system or a disk; we read and write whole objects through an API (`PUT`, `GET`, `DELETE`, `LIST`).

- Designed for **99.999999999% (11 nines) durability**; the standard classes store data across at least 3 Availability Zones.
- Virtually **unlimited capacity**; we pay for GB-month stored, requests and data transfer out.
- **Strong read-after-write consistency** (since December 2020) for all `PUT`, `DELETE` and `LIST` operations, at no extra cost.
- Buckets live in a **Region**, but general purpose bucket names are **globally unique**.
- Secure by default for new buckets: **Block Public Access on**, **ACLs disabled** (Object Ownership = bucket owner enforced, since April 2023) and **SSE-S3 encryption** (since January 2023).

```text
s3://my-app-bucket/images/2026/logo.png
     |___________| |__________________|
        bucket            object key
```

```bash
aws s3 mb s3://my-app-bucket-2026 --region ap-south-1
aws s3 cp ./logo.png s3://my-app-bucket-2026/images/logo.png
aws s3 ls s3://my-app-bucket-2026/images/
aws s3 sync ./site s3://my-app-bucket-2026/site --delete
```

## Buckets

A **bucket** is the top-level container for objects. Bucket-level settings (versioning, encryption, lifecycle, policies, logging, replication) apply to everything inside it.

Naming rules (general purpose buckets):

- 3-63 characters; lowercase letters, numbers, hyphens (dots allowed but best avoided).
- Must start and end with a letter or number, and must not look like an IP address.
- Globally unique across all AWS accounts; the name cannot be changed later.

| Bucket type | Purpose |
|-------------|---------|
| General purpose | The classic bucket; supports every storage class except Express One Zone |
| Directory bucket | Used by S3 Express One Zone; lives in one AZ; name ends with `--x-s3` |
| Table bucket | S3 Tables: managed Apache Iceberg tables for analytics |
| Vector bucket | S3 Vectors: storage and similarity search for vector embeddings |

The default quota is 10,000 general purpose buckets per account (it can be raised).

```hcl
resource "aws_s3_bucket" "app" {
  bucket = "my-app-bucket-2026"
  tags   = { Environment = "dev" }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Objects

An **object** is the data plus information about it:

| Part | Description |
|------|-------------|
| Key | Full name/path inside the bucket, e.g. `logs/2026/01/app.log` |
| Value | The bytes: 0 bytes up to **50 TB** (raised from 5 TB in December 2025) |
| Version ID | Present when versioning is enabled |
| Metadata | System (`Content-Type`, `Last-Modified`) and user-defined (`x-amz-meta-*`) |
| Tags | Up to 10 key-value pairs, usable in IAM and lifecycle rules |

- S3 has a **flat namespace**: "folders" in the console are just shared key prefixes.
- A single `PUT` can upload up to 5 GB; larger objects require **multipart upload** (recommended from about 100 MB). The high-level `aws s3 cp` does this automatically.
- **Pre-signed URLs** give temporary access to a private object without changing bucket permissions.

```bash
aws s3 presign s3://my-app-bucket-2026/images/logo.png --expires-in 3600
```

## Storage Classes

Each object has a storage class. Colder classes cost less to store but charge more (or take longer) to retrieve.

| Storage class (API name) | Designed for | AZs | Min storage duration | Retrieval |
|--------------------------|--------------|-----|----------------------|-----------|
| S3 Standard (`STANDARD`) | Frequently accessed data | 3+ | None | Milliseconds |
| S3 Intelligent-Tiering (`INTELLIGENT_TIERING`) | Unknown or changing access patterns | 3+ | None | Milliseconds (optional archive tiers: minutes to hours) |
| S3 Express One Zone (`EXPRESS_ONEZONE`) | Latency-sensitive workloads, directory buckets | 1 | None | Single-digit milliseconds |
| S3 Standard-IA (`STANDARD_IA`) | Infrequent access, fast retrieval needed | 3+ | 30 days | Milliseconds + per-GB fee |
| S3 One Zone-IA (`ONEZONE_IA`) | Infrequent, easily re-creatable data | 1 | 30 days | Milliseconds + per-GB fee |
| S3 Glacier Instant Retrieval (`GLACIER_IR`) | Archive read about once a quarter | 3+ | 90 days | Milliseconds |
| S3 Glacier Flexible Retrieval (`GLACIER`) | Archive read 1-2 times a year | 3+ | 90 days | Expedited 1-5 min, Standard 3-5 h, Bulk 5-12 h |
| S3 Glacier Deep Archive (`DEEP_ARCHIVE`) | Long-term retention, compliance | 3+ | 180 days | Standard within 12 h, Bulk within 48 h |

Notes:

- **Intelligent-Tiering** moves objects automatically: Frequent -> Infrequent Access (30 days without access) -> Archive Instant Access (90 days). Optional Archive Access and Deep Archive Access tiers can be enabled. There is a small monitoring fee per object and no retrieval fees; objects under 128 KB are not auto-tiered.
- **Express One Zone** is up to 10x faster than Standard, but data lives in a single AZ we choose.
- Standard-IA, One Zone-IA and Glacier Instant Retrieval bill a **minimum object size of 128 KB**.

## Versioning

**Versioning** keeps every version of an object in the bucket, protecting against accidental overwrites and deletes.

- Bucket states: **Unversioned** (default) -> **Enabled** -> **Suspended**. Once enabled, a bucket can never return to unversioned, only be suspended.
- A `DELETE` without a version ID adds a **delete marker**; older versions still exist and can be restored.
- Every version is billed as storage, so versioning is usually paired with lifecycle rules for noncurrent versions.
- Required for **replication** (Same-Region / Cross-Region) and **Object Lock** (WORM). **MFA Delete** can add extra protection.

```text
PUT  report.pdf                 -> version 111 (current)
PUT  report.pdf                 -> version 222 (current), 111 becomes noncurrent
DELETE report.pdf               -> delete marker 333 (current); 111 and 222 still stored
GET  report.pdf                 -> 404, because the current version is a delete marker
GET  report.pdf?versionId=222   -> returns version 222
```

```hcl
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

## Lifecycle Policies

A **lifecycle configuration** is a set of rules that S3 applies automatically to objects matching a filter (prefix, tags, object size).

| Action | What it does |
|--------|--------------|
| Transition | Move objects to a cheaper storage class after N days |
| Expiration | Delete current objects after N days |
| Noncurrent version transition / expiration | Same, but for old versions in a versioned bucket |
| Abort incomplete multipart upload | Clean up abandoned upload parts |
| Expired object delete marker | Remove delete markers that have no versions left |

```text
Day 0            Day 30              Day 90            Day 365
STANDARD  ---->  STANDARD_IA  ---->  GLACIER  ------>  expired (deleted)
```

- Transitions only move "down" to colder classes.
- Objects must stay at least 30 days in Standard before moving to Standard-IA or One Zone-IA, and by default objects smaller than 128 KB are not transitioned.
- Lifecycle actions run asynchronously, so there can be a short delay after the rule's day.

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "archive-then-expire-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

## Encryption

**At rest**, every new object is encrypted. The server-side options are:

| Option | Header value | Who manages the key | Notes |
|--------|--------------|---------------------|-------|
| SSE-S3 | `AES256` | S3 | Default for all new objects since 5 Jan 2023, no extra cost |
| SSE-KMS | `aws:kms` | AWS KMS (AWS managed or customer managed key) | Key policies, CloudTrail audit; enable **S3 Bucket Keys** to cut KMS request costs |
| DSSE-KMS | `aws:kms:dsse` | AWS KMS | Two independent layers of encryption for strict compliance |
| SSE-C | (customer key sent with each request) | Customer | Since April 2026 AWS disables SSE-C by default on new buckets (and existing buckets in accounts not using it) |

Client-side encryption (encrypting before upload) is also possible. **In transit**, S3 is accessed over HTTPS/TLS, and a bucket policy can deny any non-TLS request (see next section).

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}
```

## Bucket Policies

A **bucket policy** is a resource-based IAM policy (JSON, up to 20 KB) attached to the bucket. Unlike identity policies, it has a `Principal`, so it can grant access to other accounts or AWS services, or deny requests that do not meet conditions.

- **Block Public Access** overrides any policy that would make the bucket public, so public website buckets are best served through **CloudFront with Origin Access Control (OAC)** instead.
- Use the bucket ARN for bucket actions (`s3:ListBucket`) and `bucket/*` for object actions (`s3:GetObject`).

Example 1 - deny any request that does not use TLS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-app-bucket-2026",
        "arn:aws:s3:::my-app-bucket-2026/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

Example 2 - allow only one CloudFront distribution to read objects:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAC",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-site-bucket-2026/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
        }
      }
    }
  ]
}
```

## Common Use Cases

| Use case | Relevant S3 features |
|----------|----------------------|
| Static website / frontend assets | Private bucket + CloudFront OAC |
| Backups and disaster recovery | Versioning, Glacier classes, Cross-Region Replication |
| Data lake for analytics | Prefix partitioning, Athena, S3 Tables |
| Application logs and audit trails | Lifecycle rules, Object Lock |
| User uploads (images, documents) | Pre-signed URLs, event notifications to Lambda |
| CI/CD artifacts and container build caches | Lifecycle expiration |
| ML datasets and model artifacts | Express One Zone for hot data, Intelligent-Tiering |
| **Terraform remote state** | Versioning + encryption + native S3 locking |

Terraform S3 backend with native S3 state locking (`use_lockfile`, Terraform 1.10+; DynamoDB-based locking is now deprecated):

```hcl
terraform {
  backend "s3" {
    bucket       = "my-tf-state-2026"
    key          = "envs/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

## Key Takeaways

- S3 is object storage: **buckets** (regional, globally unique names) hold **objects** (key + data + metadata, up to 50 TB).
- Strong read-after-write consistency, 11 nines durability, and secure defaults (no public access, ACLs disabled, SSE-S3).
- Choose storage classes by access pattern; use **Intelligent-Tiering** when unsure and **lifecycle rules** to automate cost savings.
- Turn on **versioning** for important data and expire noncurrent versions to control cost.
- Use SSE-KMS with Bucket Keys when we need key control and auditing; enforce TLS with a bucket policy.
- Keep buckets private and expose content through CloudFront OAC or pre-signed URLs.

## References

- S3 User Guide: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html
- Storage classes: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html
- Lifecycle management: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html
