# Runbook — Destroy an environment

## Non-production (dev, staging)

```bash
make destroy ENV=dev
```

`deletion_protection = false` in these environments, so buckets are emptied (`force_destroy`), Aurora is
deleted without a final snapshot and KMS keys are scheduled for deletion after 7 days.

Through CI: run *Terraform apply* with `action = destroy` and `confirm = <environment>`.

## Production

Production is protected on purpose (Aurora/ALB deletion protection, Cognito `ACTIVE` deletion protection,
non-empty buckets kept, final Aurora snapshot). To decommission it intentionally:

1. Set `deletion_protection = false` in `environments/prod.tfvars` in a reviewed PR and apply it.
2. Run the destroy; a final snapshot `reservations-prod-final-<suffix>` is kept.
3. Restore the protective setting in the repository afterwards.

## Bootstrap

The state bucket has `prevent_destroy`. Destroy every environment first, then remove the lifecycle block,
empty the versioned bucket and run `terraform destroy` in `bootstrap/` if the whole project is retired.
