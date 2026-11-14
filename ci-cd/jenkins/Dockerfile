# Jenkins controller with the Terraform toolchain baked in and configured as
# code (JCasC + Job DSL). Tool versions are pinned and checksum-verified.
FROM jenkins/jenkins:2.580.2-lts-jdk21@sha256:74401de6a6f92e1afe1b02d1c8e3d0c33f263bfb5275dd8813f9150355f2367b

ARG TERRAFORM_VERSION=1.17.2
ARG TFLINT_VERSION=0.66.0
ARG TRIVY_VERSION=0.76.2

USER 0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip make \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/tools

# Terraform (HashiCorp release + SHA256SUMS)
RUN arch="$(dpkg --print-architecture)" \
 && file="terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" \
 && curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${file}" \
 && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" | grep " ${file}\$" | sha256sum -c - \
 && unzip -q "${file}" terraform -d /usr/local/bin \
 && rm -f "${file}"

# TFLint (GitHub release + checksums.txt)
RUN arch="$(dpkg --print-architecture)" \
 && file="tflint_linux_${arch}.zip" \
 && base="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}" \
 && curl -fsSLO "${base}/${file}" \
 && curl -fsSL "${base}/checksums.txt" | grep " ${file}\$" | sha256sum -c - \
 && unzip -q "${file}" tflint -d /usr/local/bin \
 && rm -f "${file}"

# Trivy (GitHub release + checksums)
RUN case "$(dpkg --print-architecture)" in amd64) arch=64bit ;; arm64) arch=ARM64 ;; esac \
 && file="trivy_${TRIVY_VERSION}_Linux-${arch}.tar.gz" \
 && base="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}" \
 && curl -fsSLO "${base}/${file}" \
 && curl -fsSL "${base}/trivy_${TRIVY_VERSION}_checksums.txt" | grep " ${file}\$" | sha256sum -c - \
 && tar -xzf "${file}" -C /usr/local/bin trivy \
 && rm -f "${file}"

# AWS CLI v2 (official installer)
RUN case "$(dpkg --print-architecture)" in amd64) arch=x86_64 ;; arm64) arch=aarch64 ;; esac \
 && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o awscliv2.zip \
 && unzip -q awscliv2.zip \
 && ./aws/install \
 && rm -rf aws awscliv2.zip

WORKDIR /
USER 1000:1000

# Plugins and configuration as code. The setup wizard is skipped because JCasC
# creates the admin user (password from JENKINS_ADMIN_PASSWORD) and security.
COPY --chown=1000:1000 plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=1000:1000 casc.yaml /usr/share/jenkins/ref/casc.yaml
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
