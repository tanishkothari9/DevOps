# DynamoDB & RDS - Database Services

Research notes on the two most common AWS managed databases: **Amazon DynamoDB** (serverless NoSQL) and **Amazon RDS** (managed relational databases).

## Part 1 - Amazon DynamoDB

DynamoDB topics: NoSQL, tables, items, attributes, partition key, sort key and use cases.

## NoSQL

**NoSQL** databases store data without a fixed relational schema and are designed to scale horizontally. Instead of normalizing data into many tables and joining them, we model data around the **access patterns** the application needs.

NoSQL families on AWS include key-value (DynamoDB), document (DocumentDB), wide-column (Keyspaces), graph (Neptune) and in-memory (ElastiCache, MemoryDB).

**Amazon DynamoDB** is a fully managed, **serverless** key-value and document database:

- No servers, patching or storage planning; single-digit millisecond latency at any scale.
- Data is replicated across **3 AZs** automatically.
- Reads are **eventually consistent** by default; **strongly consistent** reads are optional (on the table and LSIs, not GSIs).
- Extras: ACID transactions, DynamoDB Streams, TTL (auto-expire items), on-demand backups, point-in-time recovery (configurable 1-35 days), and **global tables** for multi-Region, multi-active replication.

## Tables

A **table** is a collection of items. Only the **primary key** is defined up front (and cannot be changed later); every other attribute is flexible.

| Capacity mode | How it works | Good for |
|---------------|--------------|----------|
| On-demand (`PAY_PER_REQUEST`) | Pay per read/write request, scales automatically; AWS's recommended default | New or spiky/unpredictable workloads |
| Provisioned (`PROVISIONED`) | Set read/write capacity units (RCU/WCU), optionally with auto scaling | Steady, predictable traffic |

- 1 **WCU** = one write per second for an item up to 1 KB.
- 1 **RCU** = one strongly consistent read per second (or two eventually consistent reads) for an item up to 4 KB.
- Table classes: **Standard** and **Standard-IA** (cheaper storage for rarely read tables).

```hcl
resource "aws_dynamodb_table" "orders" {
  name         = "orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"
  range_key    = "order_date"

  attribute {
    name = "customer_id"
    type = "S"
  }

  attribute {
    name = "order_date"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}
```

Only key attributes (table and index keys) are declared in `attribute` blocks; declaring other attributes makes Terraform fail.

## Items

An **item** is one record in a table, similar to a row. Items in the same table can have **different attributes**.

- Maximum item size is **400 KB**, including attribute names and values.
- No limit on the number of items in a table.
- Large blobs (images, files) belong in S3, with only the S3 key stored in the item.

```bash
aws dynamodb put-item --table-name orders --item '{
  "customer_id": {"S": "C1001"},
  "order_date":  {"S": "2026-03-15#ORD-778"},
  "total":       {"N": "1499.50"},
  "paid":        {"BOOL": true},
  "tags":        {"SS": ["gift", "express"]}
}'
```

## Attributes

An **attribute** is a name-value pair inside an item, like a column but not enforced across items.

| Category | Types (DynamoDB JSON code) |
|----------|----------------------------|
| Scalar | String `S`, Number `N`, Binary `B`, Boolean `BOOL`, Null `NULL` |
| Document | List `L`, Map `M` (nesting up to 32 levels) |
| Set | String set `SS`, Number set `NS`, Binary set `BS` |

- Attribute names are case-sensitive. Numbers are sent as strings in the API but stored and compared as numbers.
- Key attributes can only be String, Number or Binary.
- A TTL attribute must be a Number holding a Unix epoch timestamp in seconds.

## Partition Key

The **partition key** (hash key) is required in every table. DynamoDB hashes its value to decide which physical **partition** stores the item.

```text
put-item {customer_id: "C1001", ...}
                 |
          hash("C1001")
                 |
     +-----------+-----------+
     v           v           v
 [Partition 1] [Partition 2] [Partition 3]
```

- With a **simple primary key** (partition key only) the value must be **unique** per item.
- Choose a **high-cardinality**, evenly accessed value to avoid **hot partitions**; each partition supports up to 3,000 RCU and 1,000 WCU.

| Poor partition key | Better partition key |
|--------------------|----------------------|
| `status` (few values) | `order_id` |
| `country` (skewed traffic) | `customer_id` |
| `date` (all writes hit today) | `device_id` (with date in the sort key) |

## Sort Key

The optional **sort key** (range key) creates a **composite primary key** (partition key + sort key). Items with the same partition key are stored together and **sorted by the sort key**, and the pair must be unique.

- Enables efficient `Query` with conditions on the sort key: `=`, `<`, `<=`, `>`, `>=`, `BETWEEN`, `begins_with`.
- `Query` reads one partition key (efficient); `Scan` reads the whole table (slow and expensive, avoid in hot paths).

```bash
aws dynamodb query --table-name orders \
  --key-condition-expression "customer_id = :c AND begins_with(order_date, :y)" \
  --expression-attribute-values '{":c": {"S": "C1001"}, ":y": {"S": "2026-"}}'
```

Secondary indexes add more query patterns:

| | Global Secondary Index (GSI) | Local Secondary Index (LSI) |
|--|------------------------------|-----------------------------|
| Keys | Different partition and sort key | Same partition key, different sort key |
| When created | Any time | Only at table creation |
| Consistency | Eventually consistent only | Eventual or strong |
| Default limit | 20 per table | 5 per table |

## DynamoDB Use Cases

- Serverless backends (API Gateway + Lambda + DynamoDB).
- User profiles, session stores and shopping carts.
- Gaming leaderboards and player state.
- IoT and event data with TTL to expire old records.
- High-scale metadata, catalogs, idempotency keys and counters.
- Event-driven pipelines using DynamoDB Streams to trigger Lambda.
- (Legacy) Terraform state locking; new setups can use the S3 backend's native `use_lockfile`.

## Part 2 - Amazon RDS

RDS topics: relational databases, engines, DB instances, security, backups, Multi-AZ, read replicas and use cases.

## Relational Database

A **relational database** stores data in **tables** with a fixed schema of rows and columns, linked by **primary and foreign keys**, queried with **SQL**, and protected by **ACID transactions**. Data is normalized and combined with **joins**.

**Amazon RDS (Relational Database Service)** runs these databases as a managed service:

| AWS manages | We manage |
|-------------|-----------|
| Hardware, OS and DB engine patching | Schema design, queries and indexes |
| Automated backups and point-in-time restore | Parameter tuning (parameter groups) |
| Multi-AZ failover, monitoring, storage scaling | Users, grants and application access |

We do not get SSH or OS access to standard RDS instances.

## Supported Engines

| Engine | Notes |
|--------|-------|
| MySQL | Open source |
| PostgreSQL | Open source |
| MariaDB | Open source MySQL fork |
| Oracle | Bring Your Own License, or License Included for Standard Edition 2 |
| Microsoft SQL Server | License Included (Express, Web, Standard, Enterprise) |
| IBM Db2 | Bring Your Own License or license through AWS Marketplace |
| **Amazon Aurora** (MySQL-compatible, PostgreSQL-compatible) | AWS cloud-native engine in the RDS family |

Aurora separates compute from a distributed storage layer (6 copies across 3 AZs), grows storage automatically, supports up to 15 low-lag Aurora Replicas, and offers Aurora Serverless v2.

## DB Instances

A **DB instance** is an isolated database environment running one engine.

- **Instance class** sets CPU/memory, e.g. `db.t4g.micro` (burstable), `db.m7g.large` (general purpose), `db.r7g.large` (memory optimized).
- **Storage**: `gp3` (default choice), `io1`/`io2` Block Express for high IOPS; **storage autoscaling** grows the disk automatically up to a limit we set.
- **Endpoint**: a DNS name such as `app-db.abc123xyz.ap-south-1.rds.amazonaws.com` that clients connect to.
- **DB subnet group**: the private subnets (in at least two AZs) where RDS can place the instance.
- **Parameter groups** (engine settings) and **option groups** (extra features); a weekly **maintenance window**.
- An instance can be stopped for up to 7 days, after which RDS starts it again automatically.

## Security

| Layer | Control |
|-------|---------|
| Network | Private subnets, `publicly_accessible = false`, security group allowing the DB port only from the app SG |
| Encryption at rest | KMS encryption chosen **at creation** (covers storage, backups, snapshots, replicas). To encrypt an existing unencrypted DB: snapshot, copy with encryption, restore |
| Encryption in transit | SSL/TLS connections; can be enforced (e.g. `rds.force_ssl` for PostgreSQL) |
| Authentication | Master password managed by **Secrets Manager** (`manage_master_user_password`), **IAM database authentication** (MySQL, MariaDB, PostgreSQL), Kerberos for some engines |
| Access control | IAM policies for RDS API actions; database users and grants inside the engine |
| Protection and audit | Deletion protection, CloudTrail for API calls, engine logs to CloudWatch |

## Backups

- **Automated backups**: a daily snapshot during the backup window plus transaction logs uploaded about every 5 minutes. Retention is **0-35 days** (0 disables automated backups, which also blocks read replicas).
- **Point-in-time recovery (PITR)**: restore to any second within the retention period, typically up to the last 5 minutes.
- **Manual snapshots**: taken on demand, kept until we delete them, can be copied to other Regions or shared with other accounts.
- A restore always creates a **new DB instance** with a new endpoint.
- Take a **final snapshot** when deleting (`skip_final_snapshot = false`). AWS Backup can manage policies centrally.

```bash
aws rds create-db-snapshot --db-instance-identifier app-db \
  --db-snapshot-identifier app-db-before-migration

aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier app-db \
  --target-db-instance-identifier app-db-restored \
  --restore-time 2026-03-15T10:30:00Z
```

## Multi-AZ

Multi-AZ is about **high availability**, not read scaling.

| | Multi-AZ DB instance | Multi-AZ DB cluster |
|--|----------------------|---------------------|
| Layout | 1 primary + 1 standby in another AZ | 1 writer + 2 readable standbys in 3 AZs |
| Replication | Synchronous | Semi-synchronous (one standby must acknowledge) |
| Standby readable? | **No** | **Yes** (reader endpoint) |
| Typical failover | About 60-120 seconds | Typically under 35 seconds |
| Engines | All RDS engines | MySQL and PostgreSQL |

```text
          app connects to ONE endpoint (DNS)
                       |
          +------------+-------------+
          |                          |
   AZ a: PRIMARY  -- sync repl -->  AZ b: STANDBY (not readable)
          |                          ^
          +--- on failure, RDS flips DNS to the standby ---+
```

```bash
aws rds reboot-db-instance --db-instance-identifier app-db --force-failover   # test failover
```

## Read Replicas

**Read replicas** are about **read scaling** (and can help with disaster recovery).

- **Asynchronous** replication, so replicas can lag slightly behind (eventual consistency).
- Each replica has its **own endpoint**; the application sends reads there.
- Up to **15** replicas for MySQL, MariaDB and PostgreSQL; up to **5** for Oracle and SQL Server; up to **3** for Db2.
- Can be in the same AZ, another AZ or **another Region** (not for SQL Server), and can be **promoted** to a standalone database.
- The source must have automated backups enabled; a replica can itself be Multi-AZ.

```hcl
resource "aws_db_instance" "replica" {
  identifier          = "app-db-replica"
  replicate_source_db = aws_db_instance.postgres.identifier
  instance_class      = "db.t4g.micro"
  publicly_accessible = false
  skip_final_snapshot = true
}
```

## RDS Use Cases

- E-commerce orders, payments and inventory (transactions and joins).
- ERP, CRM and other line-of-business apps.
- CMS platforms such as WordPress, and SaaS application backends.
- Reporting on read replicas without slowing the primary.
- Lift-and-shift of existing MySQL, PostgreSQL, Oracle or SQL Server databases.

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "app-db-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "postgres" {
  identifier                  = "app-db"
  engine                      = "postgres"
  engine_version              = "17"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "appdb"
  username                    = "appadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  multi_az                    = true
  backup_retention_period     = 7
  deletion_protection         = true
  final_snapshot_identifier   = "app-db-final"
}
```

## DynamoDB vs RDS

| | DynamoDB | RDS |
|--|----------|-----|
| Data model | Key-value / document (NoSQL) | Relational tables (SQL) |
| Schema | Flexible; only keys defined | Fixed schema, migrations needed |
| Queries | Key lookups, `Query` on keys/indexes, PartiQL; no joins | Full SQL with joins and aggregations |
| Scaling | Automatic, horizontal, serverless | Vertical (bigger class) + read replicas |
| Servers | None to manage | DB instances (managed by AWS) |
| Availability | 3 AZs built in; global tables | Multi-AZ option; cross-Region replicas |
| Size limits | 400 KB per item | Storage up to 64 TiB for most engines |
| Pricing | Per request or provisioned capacity + storage | Per instance-hour + storage + I/O (engine-dependent) |
| Best for | Huge scale, simple access patterns, serverless | Complex relationships, ad-hoc queries, existing SQL apps |

## Key Takeaways

- **DynamoDB**: serverless NoSQL; design keys around access patterns; partition key spreads data, sort key orders it; items max 400 KB; on-demand mode by default.
- **RDS**: managed MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2 and Aurora; we keep SQL power without managing servers.
- RDS backups give PITR within 0-35 days of retention; restores create new instances.
- **Multi-AZ = availability** (standby not readable for DB instance; two readable standbys for DB cluster). **Read replicas = read scaling** (asynchronous, up to 15 for MySQL/MariaDB/PostgreSQL).
- Keep databases in private subnets, encrypted, with credentials in Secrets Manager.

## References

- DynamoDB Developer Guide: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html
- RDS User Guide: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html
- RDS Multi-AZ deployments: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html
