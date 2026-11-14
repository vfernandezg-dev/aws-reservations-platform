# ADR 0004 — ECS Fargate on Graviton (ARM64) instead of EC2

- **Status**: accepted
- **Date**: 2026-11-14

## Context

The original compute layer had two fixed EC2 instances plus an Auto Scaling Group, configured with a long
`user_data` script that installed Apache and PHP at boot. Instances had no IAM role, used IMDSv1 calls and
needed patching.

## Decision

- Run the application as a container on **ECS Fargate** with `cpu_architecture = "ARM64"`.
- Ship a **distroless, non-root** image built once per commit, pushed to ECR with an immutable tag and
  promoted across environments.
- Use the **FARGATE_SPOT** capacity provider outside production.
- Rolling deployments with **circuit breaker + rollback**; target-tracking auto scaling on CPU and
  ALB requests per target.

## Consequences

- No servers or AMIs to patch; the attack surface is the container image, which is scanned in CI and ECR.
- Graviton is ~20% cheaper than x86 for the same Fargate size; Spot saves up to ~70% in dev/staging.
- Images must be built for `linux/arm64`; the Dockerfile compiles on the native build platform and only
  the distroless runtime targets arm64, so no CPU emulation is needed.
- Distroless images have no shell, so ECS Exec is not used; debugging relies on logs and metrics.

## Alternatives considered

- **EC2 Auto Scaling** with Graviton instances: cheaper at high, steady utilisation but adds OS management.
- **AWS Lambda**: lowest idle cost, but changes the three-tier model and needs RDS Proxy or the Data API
  for efficient database connections.
- **EKS**: unnecessary operational overhead for a single service.
