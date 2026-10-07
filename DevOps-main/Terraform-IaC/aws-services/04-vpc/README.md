# VPC - Networking

Research notes on Amazon Virtual Private Cloud (VPC): our own isolated network inside AWS, where we control IP ranges, subnets, routing and firewalls.

## What is VPC?

A **VPC** is a logically isolated virtual network in one AWS **Region**. Resources such as EC2, RDS, load balancers and Lambda (when VPC-attached) are launched into it.

- A VPC **spans all Availability Zones** of its Region; each **subnet** lives in exactly **one AZ**.
- We define the IP address range (CIDR), subnets, route tables, gateways, security groups and network ACLs.
- Every Region has a **default VPC** (`172.31.0.0/16`, a public `/20` subnet in each AZ, an Internet Gateway attached) so beginners can launch instances immediately. For real projects we build our own VPC with Terraform.
- Default quota: 5 VPCs per Region (adjustable).

```text
Region: ap-south-1
+------------------------------- VPC 10.0.0.0/16 --------------------------------+
|                                                                                |
|   AZ ap-south-1a                         AZ ap-south-1b                        |
|   +------------------------+             +------------------------+            |
|   | Public  10.0.1.0/24    |             | Public  10.0.2.0/24    |            |
|   +------------------------+             +------------------------+            |
|   | Private 10.0.11.0/24   |             | Private 10.0.12.0/24   |            |
|   +------------------------+             +------------------------+            |
|                                                                                |
|   Route tables | Internet Gateway | NAT Gateways | Security Groups | NACLs     |
+--------------------------------------------------------------------------------+
```

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "main-vpc" }
}
```

## CIDR

**CIDR (Classless Inter-Domain Routing)** notation describes an IP range as `address/prefix`. The prefix is how many leading bits are fixed; the remaining bits are available for hosts.

> Number of addresses = 2^(32 - prefix)

| CIDR | Addresses | Typical use |
|------|-----------|-------------|
| `/16` | 65,536 | Whole VPC (largest allowed) |
| `/20` | 4,096 | Large subnet |
| `/24` | 256 | Common subnet size |
| `/28` | 16 | Smallest allowed subnet / VPC |

- A VPC IPv4 block must be between **/16 and /28**. We use private (RFC 1918) ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- **Do not overlap** CIDRs between VPCs or with on-premises networks if they will ever be connected (peering, Transit Gateway, VPN).
- Secondary IPv4 CIDRs and an Amazon-provided IPv6 `/56` block can be added later.

Terraform's `cidrsubnet()` carves subnets out of the VPC range:

```hcl
# cidrsubnet("10.0.0.0/16", 8, 1)  => "10.0.1.0/24"
# cidrsubnet("10.0.0.0/16", 8, 11) => "10.0.11.0/24"
locals {
  public_cidr = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
}
```

## Subnets

A **subnet** is a range of IPs inside the VPC CIDR, placed in a single AZ. Spreading subnets over at least two AZs gives high availability.

AWS **reserves 5 IP addresses** in every subnet. For `10.0.1.0/24`:

| Address | Reserved for |
|---------|--------------|
| `10.0.1.0` | Network address |
| `10.0.1.1` | VPC router |
| `10.0.1.2` | Amazon-provided DNS |
| `10.0.1.3` | Reserved for future use |
| `10.0.1.255` | Network broadcast address (broadcast is not supported, so it is reserved) |

So a `/24` gives **251 usable** addresses and a `/28` only **11**.

```hcl
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-a" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-south-1a"
  tags              = { Name = "private-a" }
}
```

## Route Tables

A **route table** contains rules (routes) that decide where traffic leaving a subnet goes.

- Every VPC has a **main route table**; we can create custom ones.
- Each subnet is associated with **exactly one** route table (the main one if we do not choose).
- Every route table has a **local route** for the VPC CIDR, which cannot be deleted, so all subnets in a VPC can reach each other.
- The **most specific route** (longest prefix match) wins.

| Destination | Target | Meaning |
|-------------|--------|---------|
| `10.0.0.0/16` | `local` | Traffic inside the VPC |
| `0.0.0.0/0` | `igw-xxxx` | Everything else to the internet (public subnet) |
| `0.0.0.0/0` | `nat-xxxx` | Everything else via NAT (private subnet) |

Other targets include VPC peering (`pcx-`), Transit Gateway (`tgw-`), VPC endpoints (`vpce-`) and network interfaces.

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
```

## Internet Gateway

An **Internet Gateway (IGW)** connects a VPC to the internet in both directions.

- Horizontally scaled, redundant and highly available; there is **no hourly charge** for the IGW itself (data transfer is charged).
- **One IGW per VPC**.
- It performs 1:1 NAT between an instance's public IPv4 address and its private IP.

For an instance to be reachable from the internet, **all** of these must be true:

1. An IGW is attached to the VPC.
2. The subnet's route table has `0.0.0.0/0 -> igw`.
3. The instance has a public IPv4 or Elastic IP.
4. The security group and network ACL allow the traffic.

For IPv6-only outbound traffic there is a separate **egress-only internet gateway**.

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}
```

## NAT Gateway

A **NAT Gateway** lets instances in **private subnets** start outbound IPv4 connections (OS updates, external APIs) while **blocking inbound connections** from the internet.

- A public NAT Gateway sits in a **public subnet** and uses an **Elastic IP**.
- A standard (zonal) NAT Gateway is **per-AZ**. For high availability we create one per AZ and point each private subnet's route table at the NAT Gateway in its own AZ. Since late 2025 there is also a **regional availability mode** that spans AZs automatically.
- It **costs money**: an hourly charge plus a per-GB data processing charge (about $0.045/hour and $0.045/GB in us-east-1), plus the public IPv4 charge. It is often a surprise item on student bills, so we delete it after labs.
- To reduce NAT traffic, use **gateway VPC endpoints** for S3 and DynamoDB (no charge).

```text
Private instance 10.0.11.25
        |
        | route 0.0.0.0/0 -> nat-xxxx
        v
NAT Gateway (public subnet, Elastic IP 13.x.x.x)
        |
        | route 0.0.0.0/0 -> igw-xxxx
        v
Internet Gateway ---> Internet  (replies come back the same way; new inbound connections are not allowed)
```

```hcl
resource "aws_eip" "nat_a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }
}
```

## Security Groups

A **security group** is a stateful firewall attached to an elastic network interface (instance level).

- **Allow rules only**; everything else is denied.
- **Stateful**: return traffic for an allowed connection is automatically allowed.
- All rules are evaluated together (no ordering).
- Can reference another security group as a source, e.g. the DB SG allows port 5432 only from the app SG. This is the cleanest way to build tiers (Terraform examples are in the EC2 and RDS notes).
- A VPC's **default security group** allows inbound traffic from members of the same group and all outbound traffic.

## Network ACLs

A **Network ACL (NACL)** is an optional, **stateless** firewall at the **subnet** level.

- Has both **allow and deny** rules.
- Rules are **numbered** (1-32766) and evaluated from the **lowest number up**; the first match wins. A final `*` rule denies everything else.
- **Stateless**: return traffic must be allowed explicitly, usually on **ephemeral ports 1024-65535**.
- The default NACL allows all traffic; a new custom NACL denies all until rules are added. Each subnet is associated with exactly one NACL.

Example inbound rules for a public web subnet:

| Rule # | Protocol | Port range | Source | Action |
|--------|----------|------------|--------|--------|
| 90 | TCP | 22 | `198.51.100.0/24` (known bad range) | DENY |
| 100 | TCP | 80 | `0.0.0.0/0` | ALLOW |
| 110 | TCP | 443 | `0.0.0.0/0` | ALLOW |
| 120 | TCP | 1024-65535 | `0.0.0.0/0` | ALLOW (return traffic) |
| `*` | All | All | `0.0.0.0/0` | DENY |

| | Security Group | Network ACL |
|--|----------------|-------------|
| Level | Network interface (instance) | Subnet |
| State | Stateful | Stateless |
| Rules | Allow only | Allow and deny |
| Evaluation | All rules together | In number order, first match wins |
| Typical use | Main access control | Extra guardrail, blocking IP ranges |

```hcl
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_a.id]
}

resource "aws_network_acl_rule" "http_in" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ephemeral_out" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
```

## Public vs Private Subnet

A subnet is not "public" because of a checkbox; it is public because of its **route table**.

| | Public subnet | Private subnet |
|--|---------------|----------------|
| Default route | `0.0.0.0/0 -> Internet Gateway` | `0.0.0.0/0 -> NAT Gateway` (or none) |
| Public IPs | Usually auto-assigned | Not assigned |
| Reachable from internet | Yes (if SG/NACL allow) | No |
| Outbound internet | Directly via IGW | Via NAT Gateway |
| Typical resources | Load balancers, NAT Gateways, bastion hosts | App servers, databases, internal services |

A typical highly available layout:

```text
                         Internet
                            |
                     Internet Gateway
                            |
          +-----------------+-----------------+
          |                                   |
   Public subnet (AZ a)                Public subnet (AZ b)
   ALB node, NAT GW a                  ALB node, NAT GW b
          |                                   |
   Private subnet (AZ a)               Private subnet (AZ b)
   App servers -> NAT GW a             App servers -> NAT GW b
          |                                   |
   DB subnet (AZ a)  <-- sync replication --> DB subnet (AZ b)
   RDS primary                         RDS standby
```

Troubleshooting checklist when "the instance cannot reach the internet": IGW attached? Route `0.0.0.0/0` present in the subnet's route table? Public IP assigned (public subnet) or NAT Gateway in place (private subnet)? Security group outbound allowed? NACL allows outbound and ephemeral return ports? VPC Flow Logs help confirm where packets are rejected.

## Key Takeaways

- A VPC is a regional, isolated network; subnets are AZ-scoped slices of its CIDR (`/16` to `/28`).
- AWS reserves **5 IPs per subnet**; plan CIDRs that never overlap.
- **Route tables** make a subnet public (`-> igw`) or private (`-> nat` / no internet route).
- The IGW is free and gives two-way internet access; the **NAT Gateway** is outbound-only, AZ-scoped and **billed hourly plus per GB**.
- **Security groups** (stateful, allow-only, instance level) are the main firewall; **NACLs** (stateless, numbered allow/deny, subnet level) are an extra layer.
- Put load balancers and NAT in public subnets, and applications and databases in private subnets across at least two AZs.

## References

- What is Amazon VPC: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html
- Subnet CIDR blocks and reserved IPs: https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html
- NAT gateways: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
