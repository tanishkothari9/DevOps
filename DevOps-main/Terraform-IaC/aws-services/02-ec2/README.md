# EC2 - Compute

Research notes on Amazon Elastic Compute Cloud (EC2): virtual servers in the AWS cloud that we can launch, resize and terminate on demand.

## What is EC2?

Amazon EC2 provides resizable virtual machines called **instances**. We pick the operating system image, CPU/memory size, storage, network placement and firewall rules, and pay only for what we run.

- An instance runs in **one subnet** of a VPC, which means **one Availability Zone**.
- EC2 is **IaaS**: AWS manages the hardware, hypervisor (the Nitro System) and data centers; we manage the OS, patches, runtime and application (shared responsibility model).
- Linux and Windows On-Demand instances are billed **per second** (60-second minimum).

```text
+---------------------------- EC2 instance -----------------------------+
|  AMI (OS image)        Instance type (vCPU/RAM)    Key pair (SSH)      |
|  EBS volumes (disks)   Security groups (firewall)  IAM role (profile)  |
|  ENI + private IP (+ optional public IP)           User data (boot)    |
+-----------------------------------------------------------------------+
```

| Pricing model | How it works | Good for |
|---------------|--------------|----------|
| On-Demand | Pay per second, no commitment | Dev/test, unpredictable load |
| Savings Plans | Commit to $/hour for 1 or 3 years | Steady production workloads |
| Reserved Instances | Commit to an instance configuration for 1 or 3 years | Steady workloads (older model) |
| Spot | Spare capacity at up to 90% off; 2-minute interruption notice | Fault-tolerant batch, CI runners |
| Dedicated Hosts / Instances | Hardware not shared with other customers | Licensing, compliance |

## AMI

An **Amazon Machine Image (AMI)** is the template used to launch an instance. It contains:

- A snapshot of the root volume (OS + pre-installed software).
- A block device mapping (which volumes to create at launch).
- Launch permissions (private, shared with accounts, or public) and the CPU architecture (`x86_64` or `arm64`).

Important facts:

- AMIs are **regional**: the same image has a different AMI ID in each Region (use `copy-image` to move it).
- Sources: AWS (Amazon Linux 2023, Ubuntu, Windows Server, RHEL), AWS Marketplace, community AMIs (verify the owner), and our own **custom / golden AMIs** (built with `create-image`, EC2 Image Builder or Packer).
- **Amazon Linux 2023** is the current Amazon Linux; Amazon Linux 2 reached end of support on 30 June 2026.

```bash
# Latest Amazon Linux 2023 AMI ID via the public SSM parameter
aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameter.Value" --output text

# Create a custom AMI from a configured instance
aws ec2 create-image --instance-id i-0123456789abcdef0 --name "web-golden-v1"
```

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

## Instance Types

The instance type decides vCPU, memory, network bandwidth and storage options. Names follow a pattern:

```text
  m 7 g d . 2xlarge
  | | | |     |
  | | | |     +-- size: nano, micro, small, medium, large, xlarge, 2xlarge ... metal
  | | | +-------- extra capability: d = local NVMe instance store
  | | +---------- processor: g = AWS Graviton (Arm), a = AMD, i = Intel
  | +------------ generation: higher number = newer hardware
  +-------------- family: m = general purpose
```

Example: `t3.micro` = family **t** (burstable), generation **3**, size **micro** (2 vCPU, 1 GiB RAM).

| Category | Example families | Typical workloads |
|----------|------------------|-------------------|
| General purpose | `t3`, `t4g`, `m7i`, `m7g`, `m8g` | Web servers, small apps, dev environments |
| Compute optimized | `c7i`, `c7g`, `c8g` | Batch processing, encoding, high-traffic APIs |
| Memory optimized | `r7i`, `r8g`, `x2idn` | Large databases, in-memory caches |
| Accelerated computing | `p5`, `g6`, `inf2`, `trn2` | ML training/inference, graphics |
| Storage optimized | `i4i`, `i8g`, `d3` | High local IOPS, data warehouses |

- **Burstable (T family)**: baseline CPU plus CPU credits for short bursts; `t3`/`t4g` run in "unlimited" mode by default, which can add surplus charges under sustained load.
- **Graviton (`g`)** instances are Arm-based and usually give better price/performance, but the software and AMI must support `arm64`.

## Key Pairs

A **key pair** is used to prove identity for SSH (Linux) or to decrypt the initial Administrator password (Windows).

- AWS stores the **public key** and places it in `~/.ssh/authorized_keys` of the default user at first boot.
- We keep the **private key**. If AWS generates the pair, the private key is downloaded once and never stored by AWS, so losing it means losing that access path.
- Types: **RSA** and **ED25519** (ED25519 is not supported for Windows). Key pairs are regional.

| AMI | Default SSH user |
|-----|------------------|
| Amazon Linux 2023 / RHEL | `ec2-user` |
| Ubuntu | `ubuntu` |
| Debian | `admin` |

```bash
aws ec2 create-key-pair --key-name devops-key --key-type ed25519 \
  --query "KeyMaterial" --output text > devops-key.pem
chmod 400 devops-key.pem
ssh -i devops-key.pem ec2-user@<public-ip>
```

```hcl
resource "aws_key_pair" "deployer" {
  key_name   = "devops-key"
  public_key = file("${path.module}/devops-key.pub")
}
```

Keyless alternatives: **SSM Session Manager** (no inbound port 22, access controlled by IAM and logged) and **EC2 Instance Connect** (pushes a short-lived key for each session).

## Security Groups

A **security group (SG)** is a virtual firewall attached to an instance's network interface.

- **Stateful**: if inbound traffic is allowed, the response is automatically allowed out (and vice versa).
- **Allow rules only**; anything not allowed is denied.
- A new SG has no inbound rules and allows all outbound traffic (Terraform removes that default egress rule, so we add it ourselves).
- Rules can reference another SG as the source (e.g. "allow 5432 only from the app SG").

Example: allow HTTP from anywhere, SSH only from one admin IP, and all outbound traffic (SG vs Network ACL is compared in the VPC notes).

```hcl
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "203.0.113.10/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

## EBS

**Elastic Block Store (EBS)** provides network-attached block volumes (virtual disks) for EC2.

- A volume lives in **one AZ** and can only attach to instances in that same AZ.
- Data persists independently of the instance. By default the root volume is deleted on termination; other volumes are kept.
- **Snapshots** are incremental, point-in-time backups stored by AWS in S3; they can be copied across Regions and used to create new volumes or AMIs.
- Supports KMS encryption (can be enabled by default per Region) and **Elastic Volumes** (change size, type or IOPS without detaching).

| Type | Class | Key characteristics | Typical use |
|------|-------|---------------------|-------------|
| `gp3` | General Purpose SSD | 3,000 IOPS and 125 MiB/s baseline at any size; IOPS/throughput provisioned independently (up to 80,000 IOPS, 2,000 MiB/s, 64 TiB) | Default for boot and most app volumes |
| `gp2` | General Purpose SSD (older) | IOPS tied to size (3 IOPS per GiB, burstable) | Legacy; migrate to gp3 |
| `io2` Block Express | Provisioned IOPS SSD | Up to 256,000 IOPS, 99.999% durability, Multi-Attach | Critical databases |
| `st1` | Throughput Optimized HDD | High sequential throughput, cannot be a boot volume | Big data, log processing |
| `sc1` | Cold HDD | Lowest cost per GB, cannot be a boot volume | Rarely accessed data |

**Instance store** is different: physically attached NVMe disks that are very fast but **ephemeral** (data is lost on stop, hibernate or terminate).

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web.availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
```

## Public vs Private IP

| | Private IPv4 | Auto-assigned public IPv4 | Elastic IP |
|--|--------------|---------------------------|------------|
| Comes from | Subnet CIDR | Amazon's pool | Allocated to our account |
| Reachable from internet | No | Yes (with IGW route + SG rule) | Yes |
| After stop/start | Kept | **Released; new IP on start** | Kept |
| After terminate | Released | Released | Stays in account until released |
| Cost | Free | $0.005/hour | $0.005/hour, attached or idle |

- Every instance gets a **private IP**; the OS only sees this address. The Internet Gateway does 1:1 NAT between the public and private IP.
- Since February 2024 AWS charges for **all public IPv4 addresses**, so we avoid public IPs on instances that do not need them.
- Instances in private subnets reach the internet outbound through a **NAT Gateway** (see VPC notes). IPv6 addresses are globally unique and free.

Checking IPs from inside the instance with **IMDSv2** (token-based Instance Metadata Service, which protects against SSRF attacks):

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4
```

## Instance Lifecycle

```text
  launch
    |
    v
 [pending] ------------> [running] ----- reboot (same host, keeps IPs)
    ^                     |      |
    |               stop /       | terminate
    |             hibernate      v
    |                 |     [shutting-down] ---> [terminated]
    |                 v           ^
    |            [stopping]       |
    |                 |           | terminate
    +---- start --- [stopped] ----+
```

| State | Meaning | Instance billed? |
|-------|---------|------------------|
| `pending` | Booting / preparing to run | No |
| `running` | Ready for use | Yes |
| `stopping` | Preparing to stop or hibernate | No if stopping, Yes if hibernating |
| `stopped` | Shut down, can be started again | No (EBS volumes and Elastic IPs still billed) |
| `shutting-down` | Preparing to terminate | No |
| `terminated` | Permanently deleted | No |

- **Stop/start**: RAM and instance store data are lost, the instance may move to new hardware, and the auto-assigned public IP changes.
- **Hibernate**: RAM is saved to the encrypted EBS root volume and restored on start. It must be enabled at launch and the instance type/OS must support it.
- **Terminate**: irreversible. Enable termination protection (`disable_api_termination = true`) for important instances.
- **Spot** instances can be stopped, hibernated or terminated by AWS with a 2-minute notice.

```bash
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,PublicIpAddress]" --output table
aws ec2 stop-instances      --instance-ids i-0123456789abcdef0
aws ec2 stop-instances      --instance-ids i-0123456789abcdef0 --hibernate
aws ec2 start-instances     --instance-ids i-0123456789abcdef0
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0
```

## Common Use Cases

| Use case | Typical setup |
|----------|---------------|
| Web servers / backend APIs | Auto Scaling group behind an Application Load Balancer |
| CI/CD runners and build agents | Spot instances or self-hosted runners |
| Batch and data processing | Compute-optimized or Spot fleets |
| ML training and inference | GPU / Trainium / Inferentia instances |
| Self-managed databases or legacy apps (lift-and-shift) | Memory/storage-optimized instances with io2/gp3 |
| Dev/test environments and labs | Small `t3`/`t4g` instances, stopped when idle |

Putting it together, a small web server in Terraform:

```hcl
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.app.name

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
  EOF

  tags = { Name = "web-server" }
}
```

## Key Takeaways

- An instance = **AMI + instance type + key pair + security groups + EBS + network placement**.
- Read instance names as family/generation/attributes/size (`m7g.large`); `g` means Graviton (Arm).
- Security groups are stateful allow-lists; keep SSH closed or restricted and prefer Session Manager.
- EBS is AZ-scoped persistent storage; `gp3` is the default choice; instance store is ephemeral.
- Auto-assigned public IPs change on stop/start and every public IPv4 address now costs money.
- Know the lifecycle states and what is billed in each; enforce IMDSv2 on every instance.

## References

- EC2 User Guide: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html
- Instance lifecycle: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html
- EBS volume types: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html
