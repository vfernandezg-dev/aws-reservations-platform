#!/usr/bin/env bash
# End-to-end checks against a deployed environment: functional paths plus the
# security controls (WAF, JWT authorizer, origin secret on the internal ALB).
#
# Usage: scripts/smoke-test.sh <env>     (run `make init ENV=<env>` first)
set -euo pipefail

ENVIRONMENT="${1:?usage: smoke-test.sh <dev|staging|prod>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_output() { terraform -chdir="$ROOT/infrastructure" output -raw "$1"; }

deployed_env="$(tf_output environment)"
if [[ "$deployed_env" != "$ENVIRONMENT" ]]; then
  echo "error: Terraform is initialised for '${deployed_env}', not '${ENVIRONMENT}'. Run: make init ENV=${ENVIRONMENT}" >&2
  exit 1
fi

BASE_URL="$(tf_output cloudfront_url)"
API_ENDPOINT="$(tf_output api_endpoint)"
failures=0

check() {
  local description="$1" expected="$2" url="$3"
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 30 "$url")"
  if [[ "$status" == "$expected" ]]; then
    printf '  PASS  %-55s %s\n' "$description" "$status"
  else
    printf '  FAIL  %-55s got %s, expected %s\n' "$description" "$status" "$expected"
    failures=$((failures + 1))
  fi
}

echo "Smoke testing ${ENVIRONMENT}: ${BASE_URL}"
check "Static site served from S3 via CloudFront"          200 "${BASE_URL}/"
check "API health through CloudFront"                      200 "${BASE_URL}/api/health"
check "Anonymous API route"                                200 "${BASE_URL}/api/public/hello"
check "Database round-trip (may wake Aurora)"              200 "${BASE_URL}/api/public/db-health"
check "Protected route without a token is rejected"        401 "${BASE_URL}/api/me"
check "WAF blocks a SQL injection probe"                   403 "${BASE_URL}/api/public/hello?id=1%27%20OR%20%271%27%3D%271"
check "Calling API Gateway directly (bypassing CloudFront)" 403 "${API_ENDPOINT}/api/health"

if ((failures > 0)); then
  echo "${failures} check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
