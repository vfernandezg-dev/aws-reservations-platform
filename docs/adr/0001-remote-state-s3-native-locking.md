# ADR 0001 — Remote state on S3 with native locking

- **Status**: accepted
- **Date**: 2026-11-14

## Context

The original project kept `terraform.tfstate` on the developer machine and committed it to git, together
with plan files and a `tfvars` containing the database password. CI started every run from that stale
file and discarded the new state afterwards. State must be shared, locked, encrypted and never in git.

## Decision

- One S3 bucket per account (created by the `bootstrap` stack) holds the state of every environment under
  `infrastructure/<env>/terraform.tfstate`.
- Locking uses **S3 conditional writes** (`use_lockfile = true`, Terraform ≥ 1.10) instead of a DynamoDB table.
- The bucket is versioned, encrypted with a dedicated customer managed KMS key, TLS-only, has Block Public
  Access and `prevent_destroy`.
- Backend settings are partial: `environments/<env>.s3.tfbackend` + the bucket name passed at `init`.

## Consequences

- No extra DynamoDB table to create, pay for or secure.
- Every environment has an isolated state and lock; `init -reconfigure` is required when switching
  environments (wrapped by `make init ENV=...`).
- Bootstrap state itself starts local; it can be migrated into the bucket after the first apply.

## Alternatives considered

- **S3 + DynamoDB locking**: deprecated in favour of native locking.
- **HCP Terraform / Terraform Cloud**: good option, but adds an external SaaS dependency to a portfolio
  project that should be reproducible with only an AWS account.
