# Jenkins pipeline (alternative to GitHub Actions)

A single, parameterised pipeline with the same quality gates as GitHub Actions, and a controller image
configured entirely as code.

| File | Purpose |
|---|---|
| [`Jenkinsfile`](Jenkinsfile) | `ENVIRONMENT` × `ACTION` (`plan`, `apply`, `destroy`): parallel gates (fmt, validate + test, TFLint, Trivy) → plan → typed confirmation → apply the saved plan → smoke test |
| [`Dockerfile`](Dockerfile) | Jenkins LTS (JDK 21, pinned by digest) + Terraform, TFLint, Trivy and AWS CLI, each download checksum-verified |
| [`plugins.txt`](plugins.txt) | Plugins installed at build time with `jenkins-plugin-cli` |
| [`casc.yaml`](casc.yaml) | JCasC: admin user, authorization, global variables, AWS credentials and the pipeline job (Job DSL) |
| [`docker-compose.yml`](docker-compose.yml) | Runs the controller locally (no Docker socket mounted) |

## Run locally

```bash
cd ci-cd/jenkins
export JENKINS_ADMIN_PASSWORD='<choose-one>'
export REPO_URL='https://github.com/<you>/aws-reservations-platform.git'
export TF_STATE_BUCKET="$(terraform -chdir=../../bootstrap output -raw state_bucket_name)"
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...   # demo only, see below
docker compose up -d --build
```

Open <http://localhost:8080>, sign in as `admin` and run **reservations-terraform**.

## Design notes

- No setup wizard and no default password: JCasC creates the only user from `JENKINS_ADMIN_PASSWORD`;
  anonymous access is denied.
- The pipeline never backs up or edits state (`state rm`, `refresh`): state lives in the remote backend
  with locking, and only the reviewed saved plan is applied.
- Static AWS keys are for a local demo only. In a real installation run the controller/agents with an
  IAM role (EC2 instance profile, EKS IRSA/Pod Identity) or use the pipeline-aws `withAWS(role: …)` step.
