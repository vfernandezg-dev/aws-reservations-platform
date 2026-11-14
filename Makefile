# Developer entry points. Run `make help` for the list.
#   make plan ENV=dev APP_IMAGE_TAG=<git-sha>
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

ENV            ?= dev
TF_DIR         := infrastructure
TF             := terraform -chdir=$(TF_DIR)
VAR_FILE       := environments/$(ENV).tfvars
PLAN_FILE      := $(ENV).tfplan
APP_IMAGE_TAG  ?= $(shell git rev-parse --short=12 HEAD 2>/dev/null)
TF_STATE_BUCKET ?= $(shell terraform -chdir=bootstrap output -raw state_bucket_name 2>/dev/null)
TFLINT         := tflint --config "$(CURDIR)/.tflint.hcl"
CHECKOV_IMAGE  := bridgecrew/checkov:3.4.5
TFDOCS_IMAGE   := quay.io/terraform-docs/terraform-docs:0.25.1

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

##@ Quality gates (no AWS credentials needed)

.PHONY: fmt
fmt: ## Format all Terraform files
	terraform fmt -recursive

.PHONY: validate
validate: ## terraform init (no backend) + validate for both stacks
	$(TF) init -backend=false -input=false >/dev/null && $(TF) validate
	terraform -chdir=bootstrap init -backend=false -input=false >/dev/null && terraform -chdir=bootstrap validate

.PHONY: lint
lint: ## TFLint with the AWS ruleset
	$(TFLINT) --init
	$(TFLINT) --recursive

.PHONY: test
test: ## Native terraform test suite (mocked AWS provider)
	$(TF) init -backend=false -input=false >/dev/null && $(TF) test

.PHONY: sec
sec: ## Trivy + Checkov security scans
	trivy config --exit-code 1 --severity HIGH,CRITICAL .
	docker run --rm -v "$(CURDIR):/src" $(CHECKOV_IMAGE) --config-file /src/.checkov.yaml -d /src/infrastructure --var-file /src/infrastructure/environments/prod.tfvars
	docker run --rm -v "$(CURDIR):/src" $(CHECKOV_IMAGE) --config-file /src/.checkov.yaml -d /src/bootstrap

.PHONY: docs
docs: ## Regenerate module READMEs with terraform-docs
	docker run --rm -u "$$(id -u):$$(id -g)" -v "$(CURDIR):/src" -w /src $(TFDOCS_IMAGE) -c .terraform-docs.yml --recursive --recursive-path modules infrastructure
	docker run --rm -u "$$(id -u):$$(id -g)" -v "$(CURDIR):/src" -w /src $(TFDOCS_IMAGE) -c .terraform-docs.yml bootstrap

.PHONY: app-test
app-test: ## Lint, type-check and test the application
	cd app && npm ci && npm run lint && npm run typecheck && npm test

.PHONY: check
check: validate lint test sec app-test ## Run every quality gate

##@ Deployment (requires AWS credentials)

.PHONY: init
init: ## Initialise the remote backend for ENV
	@test -n "$(TF_STATE_BUCKET)" || { echo "TF_STATE_BUCKET is empty: apply bootstrap/ first or export it"; exit 1; }
	$(TF) init -reconfigure -input=false \
	  -backend-config=environments/$(ENV).s3.tfbackend \
	  -backend-config="bucket=$(TF_STATE_BUCKET)"

.PHONY: plan
plan: init ## Plan ENV into a saved plan file
	$(TF) plan -input=false -var-file=$(VAR_FILE) -var="app_image_tag=$(APP_IMAGE_TAG)" -out=$(PLAN_FILE)

.PHONY: apply
apply: ## Apply the saved plan for ENV
	$(TF) apply -input=false $(PLAN_FILE)

.PHONY: destroy
destroy: init ## Destroy ENV (asks for confirmation)
	$(TF) destroy -var-file=$(VAR_FILE) -var="app_image_tag=$(APP_IMAGE_TAG)"

.PHONY: image
image: ## Build the arm64 image and push it to ECR (tag = APP_IMAGE_TAG)
	scripts/build-push.sh $(APP_IMAGE_TAG)

.PHONY: migrate
migrate: init ## Run database migrations as a one-off Fargate task
	scripts/db-migrate.sh $(ENV)

.PHONY: smoke
smoke: init ## End-to-end smoke and security checks against ENV
	scripts/smoke-test.sh $(ENV)

.PHONY: cost
cost: ## Cost estimate for every environment (Infracost)
	infracost scan .
