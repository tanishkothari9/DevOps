# IAM - Governance

Research notes on AWS Identity and Access Management (IAM): how AWS decides **who** can do **what** on **which** resources.

## What is IAM?

AWS Identity and Access Management (IAM) is the service that handles **authentication** (who is making the request) and **authorization** (is that identity allowed to do this) for every AWS API call.

- IAM is a **global** service: users, groups, roles and policies are not tied to a Region.
- IAM itself is **free**; we only pay for the resources our identities create.
- Every console click, CLI command, SDK call and `terraform apply` is a signed API request that IAM evaluates.
- The **root user** (the email used to create the account) has full access and cannot be restricted by IAM policies (only by Organizations SCPs in member accounts), so it should be locked away and used only for a few account-level tasks.

```text
   Request: "s3:PutObject on arn:aws:s3:::my-app-bucket/report.pdf"
                               |
                               v
         +--------------------------------------------+
         | IAM                                        |
         | 1. Authenticate -> who is the principal?   |
         | 2. Authorize    -> do the policies allow?  |
         +--------------------------------------------+
                     |                     |
                   ALLOW                  DENY
                     |                     |
            S3 stores the object    AccessDenied error
```

| Term | Meaning |
|------|---------|
| Principal | Something that can make a request: user, role session, federated user, AWS service |
| Identity | An IAM user, group or role |
| Policy | JSON document that allows or denies actions on resources |
| ARN | Amazon Resource Name, e.g. `arn:aws:iam::111122223333:user/alice` |

## Users

An **IAM user** represents one person or application that needs **long-term credentials**:

- A console password (for sign-in) and/or up to **2 access keys** (access key ID + secret access key) for CLI/SDK use.
- A new user has **no permissions** until a policy is attached (directly or through a group).
- Default quota is 5,000 IAM users per account.

Current AWS guidance: humans should **not** normally use IAM users. They should sign in through **IAM Identity Center** (or another identity provider) and receive temporary credentials. IAM users are kept for special cases such as break-glass access or tools that cannot assume roles.

```hcl
resource "aws_iam_user" "alice" {
  name = "alice"
  tags = { Team = "devops" }
}
```

## Groups

An **IAM group** is a collection of users. Policies attached to the group apply to every member, which is much easier to manage than attaching policies user by user.

- Groups **cannot be nested** (no group inside a group).
- A user can belong to up to **10 groups**.
- A group is **not a principal**: it cannot sign in and cannot be named in the `Principal` of a resource-based policy.

```text
Group: developers  <-- PowerUserAccess
   |-- alice
   |-- bob
Group: readonly    <-- ReadOnlyAccess
   |-- carol
   |-- bob          (one user can be in several groups)
```

```hcl
resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group_policy_attachment" "developers_poweruser" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_user_group_membership" "alice" {
  user   = aws_iam_user.alice.name
  groups = [aws_iam_group.developers.name]
}
```

## Roles

An **IAM role** is an identity with permissions but **no long-term credentials**. A trusted principal *assumes* the role and AWS STS (Security Token Service) returns **temporary credentials** (access key, secret key, session token) that expire automatically (1 hour by default; the role's maximum session duration can be set from 1 to 12 hours).

A role always has two policies:

| Policy | Question it answers |
|--------|---------------------|
| Trust policy | **Who** is allowed to assume this role? (`Principal`) |
| Permissions policy | **What** can the role do once assumed? |

Who typically assumes roles: AWS services (EC2 via an instance profile, Lambda, ECS tasks), users from another account (cross-account access), federated identities (IAM Identity Center, SAML, OIDC such as GitHub Actions), and AWS itself through service-linked roles.

```text
EC2 instance --(instance profile)--> sts:AssumeRole --> role "app-s3-reader"
                                                              |
        temporary credentials, rotated automatically  <-------+
                       |
                       v
               s3:GetObject on my-app-bucket
```

```hcl
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "app-s3-reader"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "app_s3_read" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "app" {
  name = "app-s3-reader"
  role = aws_iam_role.app.name
}
```

## Policies

A **policy** is a JSON document. Each statement has an `Effect`, `Action`, `Resource` and optional `Condition`. `Principal` only appears in resource-based policies (including role trust policies). `Version` should always be `"2012-10-17"`, the current policy language version.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListAppBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::my-app-bucket"
    },
    {
      "Sid": "ReadWriteAppObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-app-bucket/*"
    }
  ]
}
```

| Policy type | Attached to | Notes |
|-------------|-------------|-------|
| AWS managed | Users, groups, roles | Written and updated by AWS (e.g. `ReadOnlyAccess`) |
| Customer managed | Users, groups, roles | Our own reusable, versioned policies |
| Inline | One identity only | Embedded 1:1, deleted with the identity |
| Resource-based | Resources (S3 bucket, SQS queue, KMS key, role trust) | Contains a `Principal` |
| Permissions boundary | User or role | Maximum permissions identity policies can grant |
| SCP / RCP | Accounts or OUs (AWS Organizations) | Guardrails on principals (SCP) or resources (RCP); they never grant access |
| Session policy | A role or federated session | Further limits one session |

```hcl
resource "aws_iam_policy" "app_bucket_rw" {
  name = "app-bucket-rw"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-app-bucket/*"
    }]
  })
}
```

## Permissions

Permissions are the **result** of evaluating all policies that apply to a request. The core rule:

> **Explicit Deny > Explicit Allow > Implicit Deny**

```text
1. Every request starts as DENIED (implicit deny)
2. Any explicit "Deny" in any applicable policy?            -> DENY (final)
3. Do SCPs / RCPs / boundaries / session policies permit it? -> if not, DENY
4. Any explicit "Allow" in identity or resource policies?    -> ALLOW
5. Nothing allows it                                         -> DENY (implicit)
```

- Within one account, an allow in **either** the identity-based or the resource-based policy is usually enough.
- Cross-account access needs **both sides**: the caller's identity policy must allow it **and** the target's resource-based policy (or role trust policy) must allow it.
- `Condition` blocks make permissions context-aware. Example guardrail that blocks EC2 actions outside Mumbai:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyEc2OutsideMumbai",
      "Effect": "Deny",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": { "aws:RequestedRegion": "ap-south-1" }
      }
    }
  ]
}
```

Debugging tools: the IAM policy simulator, `aws iam simulate-principal-policy`, and CloudTrail events with `AccessDenied` errors.

## Least Privilege

**Least privilege** means granting only the permissions needed for a task, on only the required resources, for only as long as needed.

| Too broad | Least privilege |
|-----------|-----------------|
| `"Action": "*", "Resource": "*"` | `"Action": "s3:GetObject", "Resource": "arn:aws:s3:::reports/*"` |
| `AdministratorAccess` on a CI pipeline | Role that can only update one ECS service and one S3 bucket |
| Long-lived access keys on a laptop | Identity Center session that expires |

How to get there in practice:

- Start with AWS managed policies while learning, then replace them with scoped customer managed policies.
- Use **IAM Access Analyzer**: generate policies from real CloudTrail activity, find unused roles/keys/permissions, and validate policies.
- Check **last accessed** information to remove services a role never uses.
- Use **permissions boundaries** when delegating IAM to teams, and conditions (`aws:SourceIp`, `aws:PrincipalOrgID`, `aws:MultiFactorAuthPresent`).

```bash
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://policy.json
```

## IAM Best Practices

1. **Protect the root user**: enable MFA, never create root access keys, use it only for root-only tasks. In AWS Organizations, centralized root access management can remove root credentials from member accounts.
2. **Federate humans** through IAM Identity Center so people get temporary credentials instead of IAM users with passwords and keys.
3. **Use roles for workloads**: instance profiles, Lambda execution roles, EKS Pod Identity, OIDC for CI/CD. Never hard-code access keys in code, AMIs or Git.
4. **Require MFA**, preferably phishing-resistant (passkeys / FIDO2 security keys).
5. **Rotate or remove long-term keys** where they still exist; delete unused users, roles and credentials.
6. **Apply least privilege** and review it regularly with Access Analyzer.
7. **Add guardrails** across accounts with SCPs, RCPs and permissions boundaries.
8. **Use groups** (or Identity Center permission sets) instead of attaching policies to individuals.
9. **Monitor and audit**: CloudTrail, the IAM credential report, Access Analyzer findings.
10. **Manage IAM as code** (Terraform) so every permission change is reviewed in a pull request.

## Common Use Cases

| Use case | IAM building block |
|----------|--------------------|
| EC2 application reads files from S3 | Role + instance profile |
| Lambda function writes to DynamoDB | Lambda execution role |
| GitHub Actions runs `terraform apply` | OIDC identity provider + role (no stored keys) |
| Developers access dev/stage/prod accounts | IAM Identity Center + permission sets |
| Security account reads logs in prod account | Cross-account role with a trust policy |
| Share an S3 bucket with a partner account | Bucket (resource-based) policy |
| Block unused Regions for the whole company | SCP in AWS Organizations |
| Let a team create roles without escalating | Permissions boundary |

Example trust policy for GitHub Actions OIDC (only the `main` branch of one repo can assume the role):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## Key Takeaways

- IAM answers "who can do what on which resource" for every AWS API call; it is global and free.
- Users and groups are for long-term identities; **roles with temporary credentials** are the preferred pattern for both people (via Identity Center) and workloads.
- Policies are JSON; evaluation is **explicit deny > explicit allow > implicit deny**.
- Least privilege is a continuous process: scope actions and resources, use conditions, and prune with Access Analyzer.
- Lock down root, require MFA, avoid long-lived keys, and manage IAM through Terraform.

## References

- IAM User Guide: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html
- Policy evaluation logic: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html
- Security best practices in IAM: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
