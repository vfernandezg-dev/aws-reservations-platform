# ADR 0005 — RDS for PostgreSQL 18 with RDS-managed credentials

- **Status**: accepted (supersedes the initial Aurora Serverless v2 choice)
- **Date**: 2026-11-14

## Context

The original database was RDS MySQL 8.0, which reached end of standard support on 31 July 2026 (instances
are now billed for Extended Support). Its master password was a Terraform variable, stored in `tfvars`,
in the state file and in a separately managed Secrets Manager secret.

The redesign first targeted **Aurora Serverless v2** (MySQL 8.4, then PostgreSQL) for its scale-to-zero
capability. The first real deployment ran in an AWS account on the **Free plan**, which rejected it twice:

1. `FreeTierRestrictionError`: only the `aurora-postgresql` engine is available on Free-plan accounts.
2. `FreeTierRestrictionError`: Aurora clusters on Free-plan accounts must use **express configuration**,
   which creates the cluster **outside the VPC** (reachable through an internet access gateway, no
   security groups) and is not supported by the Terraform AWS provider.

A database outside the VPC contradicts the core security design (isolated data subnets, SG-to-SG access
only from the application tier).

## Decision

- Use **RDS for PostgreSQL 18** on **Graviton** (`db.t4g.micro` in dev/staging, `db.t4g.small` in prod),
  gp3 storage with storage autoscaling, in the isolated data subnets, never publicly accessible.
- Production runs **Multi-AZ** (synchronous standby, automatic failover) with Enhanced Monitoring and
  Performance Insights.
- `manage_master_user_password = true`: RDS generates and rotates the password in Secrets Manager,
  encrypted with the environment's KMS key; ECS injects it into the task at start-up.
- Enforce TLS (`rds.force_ssl = 1`), enable IAM database authentication, log every connection stage,
  disconnections, DDL and slow statements, and export the PostgreSQL and IAM-auth-error logs.
- Keep the PostgreSQL schema ported from the legacy MySQL model (`uuidv7()` keys, `CHECK` constraints,
  identity columns, `JSONB`, PL/pgSQL triggers, one transaction per migration).
- A `moved` block maps the former `module.aurora` state to `module.database`.

## Consequences

- The whole platform deploys on Free-plan accounts as well as paid ones, with the data tier private.
- The database runs 24/7 (no scale to zero): ~$14/month in dev, ~$51/month for Multi-AZ in prod.
- No password exists in code, variables, CI logs or Terraform state.
- Failover takes ~1–2 minutes (Aurora is faster); health checks never depend on the database.
- **Upgrade path**: on a paid account, Aurora Serverless v2 PostgreSQL can replace the module without
  application changes (same engine, port and secret handling).

## Alternatives considered

- **Aurora Serverless v2 (PostgreSQL)**: scale to zero and fast failover, but unavailable inside a VPC on
  Free-plan accounts.
- **Aurora express configuration**: fastest to create, but public networking, default settings and no
  Terraform support.
- **Upgrading the account to the Paid plan**: keeps Aurora, but moves charges to a card once credits run out.
