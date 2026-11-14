# ADR 0003 — HTTP API + VPC Link + internal ALB

- **Status**: accepted
- **Date**: 2026-11-14

## Context

The original design was CloudFront → REST API Gateway → **public** ALB → EC2. Anyone could reach the ALB
directly and skip WAF and authentication, and the API methods required IAM auth plus an API key that
never existed, so the API was unusable.

## Decision

- CloudFront routes `/api/*` to an **API Gateway HTTP API** with a **Cognito JWT authorizer**.
- The HTTP API reaches the application through a **VPC Link** to an **internal ALB** in private subnets.
- CloudFront injects a secret `X-Origin-Verify` header; the ALB forwards only requests carrying it
  (default action: 403). This blocks calls to the public `execute-api` endpoint that would bypass WAF.
- The ALB listener is HTTP: the hop stays inside private subnets and is restricted by security groups;
  TLS terminates at CloudFront and API Gateway.

## Consequences

- No load balancer or task is reachable from the internet.
- HTTP APIs are cheaper and faster than REST APIs and support JWT authorizers natively; WAF stays at the
  CloudFront layer (HTTP APIs cannot attach WAF directly).
- The origin secret must be rotated by replacing `random_password.origin_verify` (one apply updates both ends).
- Checkov flags the HTTP listener; the exception is documented inline.

## Alternatives considered

- **CloudFront VPC origins → internal ALB**: removes API Gateway, but authentication would move to the
  application or to ALB OIDC (which needs HTTPS and a custom domain). Listed on the roadmap.
- **Private CA certificate on the ALB**: end-to-end TLS, but a general-purpose AWS Private CA costs ~$400/month.
