#!/usr/bin/env bash
# Run the database migrations as a one-off ECS Fargate task inside the private
# application subnets (the database is not reachable from anywhere else).
# Credentials are injected by ECS from the RDS-managed secret.
#
# Usage: scripts/db-migrate.sh <env>     (run `make init ENV=<env>` first)
set -euo pipefail

ENVIRONMENT="${1:?usage: db-migrate.sh <dev|staging|prod>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_output() { terraform -chdir="$ROOT/infrastructure" output -raw "$1"; }

deployed_env="$(tf_output environment)"
if [[ "$deployed_env" != "$ENVIRONMENT" ]]; then
  echo "error: Terraform is initialised for '${deployed_env}', not '${ENVIRONMENT}'. Run: make init ENV=${ENVIRONMENT}" >&2
  exit 1
fi

cluster="$(tf_output ecs_cluster_name)"
task_definition="$(tf_output migration_task_definition_arn)"
log_group="$(tf_output ecs_log_group_name)"
security_group="$(tf_output app_security_group_id)"
subnets="$(terraform -chdir="$ROOT/infrastructure" output -json app_subnet_ids | tr -d '[]" \n')"

echo "Starting migration task in ${cluster}..."
task_arn="$(aws ecs run-task \
  --cluster "$cluster" \
  --task-definition "$task_definition" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${subnets}],securityGroups=[${security_group}],assignPublicIp=DISABLED}" \
  --started-by "db-migrate" \
  --query 'tasks[0].taskArn' \
  --output text)"

echo "Waiting for ${task_arn##*/} (usually under a minute)..."
aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task_arn"

exit_code="$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task_arn" \
  --query 'tasks[0].containers[0].exitCode' --output text)"

echo "--- task logs ---"
aws logs get-log-events \
  --log-group-name "$log_group" \
  --log-stream-name "ecs/app/${task_arn##*/}" \
  --query 'events[].message' \
  --output text | tr '\t' '\n'

if [[ "$exit_code" != "0" ]]; then
  echo "Migration failed (exit code ${exit_code})" >&2
  exit 1
fi
echo "Migrations applied."
