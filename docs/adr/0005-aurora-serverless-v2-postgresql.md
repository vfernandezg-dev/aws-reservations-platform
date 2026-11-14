# ADR 0005 — Aurora Serverless v2 (PostgreSQL 18) with RDS-managed credentials

- **Status**: accepted (supersedes the initial Aurora MySQL 8.4 choice)
- **Date**: 2026-11-14

## Context

The original database was RDS MySQL 8.0, which reached end of standard support on 31 July 2026 (instances
are now billed for Extended Support). Its master password was a Terraform variable, stored in `tfvars`,
in the state file and in a separately managed Secrets Manager secret.

The redesign first targeted Aurora MySQL 8.4. The first real deployment, in an AWS account on the
**Free plan**, failed with `FreeTierRestrictionError`: Free-plan accounts can only create Aurora clusters
with the `aurora-postgresql` engine. PostgreSQL is also the most widely adopted open-source database for
new projects and offers transactional DDL, `JSONB` and native UUIDv7 keys.

## Decision

- Use **Aurora PostgreSQL 18** with **Serverless v2** instances.
- Allow **scale to zero** (`min_capacity = 0`, auto-pause after 5 minutes) in dev and staging; keep a warm
  minimum and a reader in another AZ in production.
- Set `manage_master_user_password = true`: RDS generates and rotates the password in Secrets Manager,
  encrypted with the environment's KMS key. ECS injects the secret fields into the task at start-up.
- Enforce TLS (`rds.force_ssl = 1`), enable IAM database authentication, log connections, DDL and slow
  statements, and export the PostgreSQL and IAM-auth-error logs.
- Port the legacy MySQL schema: `UUID DEFAULT uuidv7()` keys, `CHECK` constraints instead of `ENUM`,
  identity columns, `JSONB`, a shared `set_updated_at()` trigger instead of `ON UPDATE CURRENT_TIMESTAMP`,
  and PL/pgSQL trigger functions. Each migration runs in its own transaction.

## Consequences

- The platform deploys on Free-plan accounts (no card charges while credits last) as well as paid accounts.
- Idle non-production databases cost little more than their storage.
- No password exists in code, variables, CI logs or Terraform state.
- The first connection after a pause takes ~15 seconds; health checks therefore never depend on the database.
- The placeholder application connects with the master secret; a dedicated least-privilege user is on the roadmap.

## Alternatives considered

- **Aurora MySQL 8.4**: closest to the original schema, but unavailable on Free-plan accounts.
- **RDS MySQL/PostgreSQL on db.t4g**: simple and predictable, but billed 24/7 and with slower failover.
