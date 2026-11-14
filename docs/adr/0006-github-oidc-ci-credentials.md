# ADR 0006 — GitHub OIDC instead of static access keys

- **Status**: accepted
- **Date**: 2026-11-14

## Context

CI needs AWS access to plan, apply and push images. Long-lived access keys stored as CI secrets can leak,
are rarely rotated and are hard to scope.

## Decision

The `bootstrap` stack creates the GitHub OIDC identity provider and three roles whose trust policies are
restricted by the token `sub` claim:

| Role | Trusted subjects | Permissions |
|---|---|---|
| `gha-plan` | pull requests and `main` of this repository | `ReadOnlyAccess` + state bucket/lock objects + state KMS key |
| `gha-apply` | jobs bound to the GitHub Environments `dev`, `staging`, `prod` | `PowerUserAccess` + IAM limited to `<project>-*` roles |
| `gha-ecr-push` | `main` of this repository | push to the application ECR repository |

Apply jobs run in GitHub Environments with required reviewers, so assuming the apply role always
requires an explicit human approval of a published plan.

## Consequences

- Credentials live for at most one hour and exist only inside the job.
- Pull requests from forks never receive AWS credentials (workflows skip when repository variables are absent).
- The apply role is broad by necessity (it creates most resource types); IAM is the main escalation path and
  is limited to project-prefixed roles. A permissions boundary is a further hardening step.
