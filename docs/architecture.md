# Architecture deep dive

This document complements the [README](../README.md) with the details behind each tier:
how traffic flows, how failures are contained, and where each security control lives.

## 1. Traffic flows

| Flow | Path | Notes |
|---|---|---|
| Static site | Viewer → CloudFront → S3 (OAC) | `CachingOptimized`; bucket readable only by this distribution (`AWS:SourceArn` condition) |
| Anonymous API | Viewer → CloudFront → HTTP API `ANY /api/public/{proxy+}` → VPC Link → ALB → task | `x-user-*` headers removed by API Gateway before the integration |
| Authenticated API | Same path, route `ANY /api/{proxy+}` | JWT authorizer validates issuer, audience/client_id and expiry; `sub`/`email` claims overwrite `x-user-*` |
| Health | `GET /api/health` (public), `GET /health` (ALB only) | ALB health checks never touch the database, so a paused Aurora does not drain tasks |
| Database | Task → Aurora writer endpoint (TLS, port 5432) | Credentials injected by ECS from the RDS-managed secret |
| Migrations | `scripts/db-migrate.sh` → one-off Fargate task (same image) | Runs inside the app subnets; files applied once, tracked in `schema_migrations` |
| Egress to AWS APIs | Task → NAT gateway (dev/staging) or interface endpoints (prod) | ECR image layers use the free S3 gateway endpoint |
| Logs | ALB → S3, CloudFront (logging v2) → S3, VPC Flow Logs → S3, app/API/DB/WAF → CloudWatch Logs | Central log bucket with lifecycle; CloudWatch groups encrypted with KMS |

### Why the ALB is internal and still checks a header

API Gateway HTTP APIs always expose a default `execute-api` endpoint. Without extra protection a client
could call it directly and skip CloudFront and WAF. CloudFront therefore adds a 64-character random
`X-Origin-Verify` header (stored only in Terraform state and the CloudFront config). HTTP API forwards
headers unchanged to the private integration, and the ALB listener forwards only when the header
matches; everything else receives a 403. `scripts/smoke-test.sh` verifies this on every deployment.

## 2. Failure domains and recovery

| Failure | Impact | Mitigation |
|---|---|---|
| One AZ down | Half of the tasks/NAT/ALB nodes | Tasks rebalanced across AZs; prod has a NAT per AZ; Aurora fails over to the reader in the other AZ |
| Task crash / bad deploy | Errors on some requests | Container + ALB health checks; deployment circuit breaker rolls back automatically |
| Traffic spike | Latency | Target tracking (CPU, requests per target), Aurora ACU scaling, API Gateway throttling, WAF rate limit |
| Aurora paused (dev) | First query ~15 s | 30 s connect timeout in the app; health checks independent of the DB |
| Data corruption / human error | Data loss | PITR within the retention window, final snapshot on deletion, deletion protection in prod |
| Region outage | Full outage | Out of scope today; multi-region DR is on the roadmap |

## 3. Security controls map

| Threat | Control | Where |
|---|---|---|
| Web exploits (SQLi, Log4Shell, bad bots) | WAF managed rule groups, IP reputation, rate limit | `modules/waf` |
| WAF bypass via `execute-api` | Origin secret header + internal ALB 403 | `modules/cdn`, `modules/alb` |
| Identity spoofing | JWT authorizer; identity headers stripped/overwritten | `modules/api` |
| Lateral movement | SG-to-SG chain, isolated data subnets, no public IPs | `modules/security`, `modules/network` |
| Credential leakage | RDS-managed password, ECS secrets injection, OIDC in CI, gitleaks | `modules/aurora`, `modules/ecs`, `bootstrap`, CI |
| Data exposure at rest | KMS CMKs (Aurora, secret, logs, SNS, state), SSE-S3 for buckets | `modules/kms`, `bootstrap` |
| Data exposure in transit | HTTPS-only viewers, TLS to origins, `rds.force_ssl` | `modules/cdn`, `modules/aurora` |
| Container compromise | Distroless non-root, read-only rootfs, task role without permissions | `app/Dockerfile`, `modules/ecs` |
| Supply chain | SHA-pinned actions, digest-pinned images, SBOM, provenance attestation, Dependabot | `.github/` |
| Drift / unreviewed change | PR plans, environment approvals, saved-plan apply, `check` blocks | `.github/workflows`, `infrastructure/checks.tf` |

## 4. Observability

- **Metrics & alarms** (`modules/monitoring`): ALB 5xx, target 5xx, unhealthy targets, ECS CPU and memory,
  API Gateway 5xx, Aurora ACU utilisation and deadlocks (regional topic); CloudFront 5xx rate and WAF
  blocked-request spikes (us-east-1 topic). All alarms notify KMS-encrypted SNS topics.
- **Dashboard**: one per environment, linked from the `dashboard_url` output.
- **Logs**: API access logs (JSON), container logs, Aurora PostgreSQL logs (connections, DDL, slow statements, IAM auth errors), WAF logs (redacted),
  ALB/CloudFront/VPC Flow Logs in S3.
- **Container Insights** with enhanced observability on the ECS cluster.

## 5. Naming, tagging and state

- Every resource is named `<project>-<environment>[-<component>]` (e.g. `reservations-prod-app`).
- `default_tags`: `Project`, `Environment`, `ManagedBy`, `Repository`, `Owner`, `CostCenter`.
- State: `s3://<project>-tfstate-<account>/infrastructure/<env>/terraform.tfstate`, KMS-encrypted,
  versioned, locked with S3 conditional writes (`use_lockfile`).
