#!/usr/bin/env bash
# Build the application image for linux/arm64 (Graviton) and push it to the
# shared ECR repository created by the bootstrap stack.
#
# Usage: scripts/build-push.sh [tag]     (default: short git commit SHA)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-$(git -C "$ROOT" rev-parse --short=12 HEAD)}"
REGION="${AWS_REGION:-us-east-1}"

if [[ -n "$(git -C "$ROOT" status --porcelain -- app)" ]]; then
  echo "warning: app/ has uncommitted changes; tag ${TAG} will not match a commit" >&2
fi

REPO_URL="$(terraform -chdir="$ROOT/bootstrap" output -raw ecr_repository_url)"
REGISTRY="${REPO_URL%%/*}"

aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin "$REGISTRY"

docker buildx build \
  --platform linux/arm64 \
  --provenance=true \
  --sbom=true \
  --tag "${REPO_URL}:${TAG}" \
  --push \
  "$ROOT/app"

echo "Pushed ${REPO_URL}:${TAG}"
echo "Deploy it with: make plan apply ENV=dev APP_IMAGE_TAG=${TAG}"
