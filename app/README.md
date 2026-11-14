# Reservations API (placeholder)

Minimal service that exercises every layer of the platform. It is intentionally small: the focus of
this repository is the infrastructure.

| Endpoint | Auth | Description |
|---|---|---|
| `GET /health` | – | ALB health check (never touches the database) |
| `GET /api/health` | – | Liveness through CloudFront → API Gateway → ALB |
| `GET /api/public/hello` | – | Version, Availability Zone and task ID (ECS metadata v4) |
| `GET /api/public/db-health` | – | `SELECT 1` against RDS PostgreSQL over TLS |
| `GET /api/me` | Cognito JWT | Returns the verified `sub`/`email` forwarded by API Gateway |

**Stack**: Node.js 26 LTS, TypeScript 6 (strict), Fastify 5, node-postgres (`pg`), Vitest, ESLint (type-checked).
**Image**: multi-stage build → `gcr.io/distroless/nodejs26-debian13:nonroot`, both bases pinned by digest,
`linux/arm64` for Graviton, ~64 MB.

## Develop

```bash
npm ci
npm run lint && npm run typecheck && npm test

# Full local stack: PostgreSQL 18 + API, then apply the migrations
docker compose up -d --build --wait
docker compose run --rm migrate
curl localhost:8080/api/public/db-health
docker compose down -v
```

Set `API_PORT=18080` / `DB_HOST_PORT=15432` if ports 8080 / 5432 are busy on your machine.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | Listen port |
| `APP_VERSION` | `dev` | Reported version (the image tag in AWS) |
| `LOG_LEVEL` | `info` | Pino log level |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | – | RDS PostgreSQL endpoint (set by Terraform) |
| `DB_USER`, `DB_PASSWORD` | – | Injected by ECS from the RDS-managed secret |
| `DB_TLS` | `true` | Set `false` only for the local PostgreSQL container |

## Migrations

SQL files in [`migrations/`](migrations) (PostgreSQL 18: `uuidv7()` keys, `JSONB`, PL/pgSQL triggers) are
applied in order by `dist/migrate.js`, each in its own transaction, and recorded in `schema_migrations`. In AWS they run as a one-off Fargate task: see
[the runbook](../docs/runbooks/db-migrate.md).
