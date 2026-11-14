# Runbook — Database migrations

Aurora lives in isolated subnets with no route to the internet, so migrations run **inside the VPC** as a
one-off Fargate task that uses the same image as the API (`node dist/migrate.js`).

```bash
make migrate ENV=dev
```

What happens:

1. `scripts/db-migrate.sh` checks that Terraform is initialised for the requested environment.
2. It starts the `<name>-migrate` task definition in the app subnets with the app security group.
3. The task receives `DB_USER`/`DB_PASSWORD` from the RDS-managed secret and connects over TLS.
4. Files in `app/migrations/` are applied in lexical order; each one is recorded in `schema_migrations`
   and never runs twice. Every statement is idempotent (`IF NOT EXISTS`), so a partially failed file can
   simply be re-run after fixing it.
5. The script waits for the task, prints its logs and exits with the task's exit code.

If Aurora is paused (dev/staging), the first connection resumes it (~15 s); the connect timeout is 30 s.

## Adding a migration

1. Create `app/migrations/NNN_description.sql` (next number, never edit an applied file).
2. Test locally: `cd app && docker compose up -d --build --wait && docker compose run --rm migrate`.
3. Merge → new image → deploy → `make migrate ENV=<env>`.

Triggers need no `DELIMITER`: each file is sent as one multi-statement query and MySQL parses
`BEGIN … END` blocks itself. The cluster parameter `log_bin_trust_function_creators = 1` lets the
non-SUPER master user create them.
