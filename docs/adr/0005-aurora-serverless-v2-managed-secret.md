# ADR 0005 — Aurora Serverless v2 (MySQL 8.4) with RDS-managed credentials

- **Status**: accepted
- **Date**: 2026-11-14

## Context

The original database was RDS MySQL 8.0, which reached end of standard support on 31 July 2026 (instances
are now billed for Extended Support). The master password was a Terraform variable, stored in `tfvars`,
in the state file and in a separately managed Secrets Manager secret.

## Decision

- Use **Aurora MySQL 8.4-compatible** (`8.4.mysql_aurora.8.4.x`) with **Serverless v2** instances.
- Allow **scale to zero** (`min_capacity = 0`, auto-pause after 5 minutes) in dev and staging; keep a warm
  minimum and a reader in another AZ in production.
- Set `manage_master_user_password = true`: RDS generates and rotates the password in Secrets Manager,
  encrypted with the environment's KMS key. ECS injects the secret fields into the task at start-up.
- Enforce TLS, enable IAM database authentication, export audit/error/slow-query logs.

## Consequences

- Idle non-production databases cost little more than their storage.
- No password exists in code, variables, CI logs or Terraform state.
- The first connection after a pause takes ~15 seconds; health checks therefore never depend on the database.
- The placeholder application connects with the master secret; a dedicated least-privilege user is on the roadmap.

## Alternatives considered

- **RDS MySQL 8.4 on db.t4g**: simple and predictable, but billed 24/7 and with slower failover.
- **Aurora PostgreSQL**: popular choice, but would require porting the existing MySQL schema.
