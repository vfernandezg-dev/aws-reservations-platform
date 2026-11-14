# Runbook — Deploy an environment

## First deployment (local)

1. **Credentials**: an AWS profile with administrator access for the bootstrap; afterwards the apply role is enough.
   ```bash
   export AWS_PROFILE=<profile> AWS_REGION=us-east-1
   aws sts get-caller-identity
   ```
2. **Bootstrap** (once per account):
   ```bash
   cd bootstrap
   cp terraform.tfvars.example terraform.tfvars   # github_repository = "owner/repo"
   terraform init && terraform apply
   cd ..
   ```
   If the account already has a GitHub OIDC provider, set `create_github_oidc_provider = false`.
   For repositories with immutable OIDC subjects (default for new ones) also set
   `github_oidc_subject_prefix` to the output of
   `gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix`.
3. **Image**: `make image` builds `app/` for `linux/arm64` and pushes `<ecr>/reservations-app:<short-sha>`.
4. **Plan and apply**:
   ```bash
   make plan  ENV=dev        # review the plan output
   make apply ENV=dev
   ```
   The first apply takes ~15–20 minutes (CloudFront and Aurora are the slowest resources).
5. **Schema**: `make migrate ENV=dev` (see [db-migrate](db-migrate.md)).
6. **Verify**: `make smoke ENV=dev`, then open the `cloudfront_url` output in a browser.

## Deploying a new application version

- **CI/CD**: merge to `main` → the *App* workflow pushes `<ecr>:<commit-sha>` → run *Terraform apply*
  with `app_image_tag = <commit-sha>` → approve in the GitHub Environment → smoke test runs automatically.
- **Local**: `make image && make plan apply ENV=dev`.

ECS performs a rolling update; if new tasks fail their health checks the circuit breaker rolls back to the
previous task definition.

## Promoting to staging / prod

Use the same immutable image tag that passed in the lower environment:

```bash
make plan  ENV=prod APP_IMAGE_TAG=<tag-from-dev>
make apply ENV=prod
```

## Configuring GitHub Actions

1. `terraform -chdir=bootstrap output github_actions_variables` → create those repository **variables**.
2. Create the GitHub Environments `dev`, `staging`, `prod`; add required reviewers to `staging`/`prod`.
3. Optional: install the Infracost GitHub App for cost diffs on pull requests.
