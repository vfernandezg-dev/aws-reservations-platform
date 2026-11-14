# ADR 0002 — Single root module, one tfvars per environment

- **Status**: accepted
- **Date**: 2026-11-14

## Context

Environments must have the same topology and differ only in size, redundancy and protection.
The original code selected settings from a large `locals` map keyed by environment, mixing
configuration with logic.

## Decision

- One root module (`infrastructure/`) composes all modules.
- Each environment is a `environments/<env>.tfvars` file plus `environments/<env>.s3.tfbackend`.
- Every variable is typed, documented and validated (enum for `environment`, ranges, cross-variable checks).

## Consequences

- Promotion is reviewable as a small `tfvars` diff; drift between environments is impossible by construction.
- A change to a module affects all environments, so plans for dev and prod are shown on every PR.
- Truly different topologies would need feature flags (e.g. `interface_endpoint_services`, `instance_count`)
  rather than separate code paths.

## Alternatives considered

- **Directory per environment** (`envs/dev/main.tf`, …): explicit but duplicates wiring code.
- **Terraform workspaces**: hides which environment is active and shares one backend config.
- **Terragrunt**: powerful, but an extra tool for a single-stack project.
