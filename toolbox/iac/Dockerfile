# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# iac-toolbox — Infrastructure-as-Code / misconfiguration scanning, layered on the base.
#   = base + Checkov (Terraform, Dockerfiles, Kubernetes, Helm, CloudFormation, ...).
# STATIC ANALYSIS ONLY.
#
# BASE is pinned by digest in CI. Keep the ARG in sync with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

ARG CHECKOV_VERSION=3.3.7

LABEL org.opencontainers.image.title="iac-toolbox" \
      org.opencontainers.image.description="Infrastructure-as-Code / misconfiguration scanning — security-toolbox-base + Checkov (Terraform, Dockerfiles, K8s, Helm, CloudFormation)." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

USER root
RUN set -eux; \
    pip install --no-cache-dir "checkov==${CHECKOV_VERSION}"
USER toolbox

# `docker run <image>` prints the tool version as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'iac-toolbox — pinned IaC scanner:'; checkov --version; true"]
