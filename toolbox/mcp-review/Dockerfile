# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# mcp-review-toolbox — MCP-server review scanners layered on security-toolbox-base.
#   = base (betterleaks, trufflehog, osv-scanner, syft) + pip-audit + snyk-agent-scan.
# STATIC ANALYSIS ONLY. Dynamic analysis — actually running an untrusted MCP server,
# proxy/traffic interception — stays in the caller's isolated environment.
#
# BASE is pinned by digest in CI (build-toolbox.yml passes …@sha256:…). The default
# tag lets a standalone `docker build` still resolve once the base is published.
# Keep the ARG versions below in sync with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

ARG PIP_AUDIT_VERSION=2.10.1
# snyk-agent-scan is the renamed successor to invariantlabs-ai/mcp-scan (the PyPI
# `mcp-scan` package is now a redirect stub). Same version line (0.5.12).
ARG SNYK_AGENT_SCAN_VERSION=0.5.12

LABEL org.opencontainers.image.title="mcp-review-toolbox" \
      org.opencontainers.image.description="Pinned static security scanners for MCP server review — security-toolbox-base + pip-audit + snyk-agent-scan." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

# Python static-analysis tools, pinned exact versions. Install as root; run as toolbox
# (the base image already created the unprivileged user and set USER toolbox).
USER root
RUN set -eux; \
    pip install --no-cache-dir \
      "pip-audit==${PIP_AUDIT_VERSION}" \
      "snyk-agent-scan==${SNYK_AGENT_SCAN_VERSION}"
USER toolbox

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'mcp-review-toolbox — pinned scanners:'; betterleaks version; trufflehog --version 2>&1 | head -1; osv-scanner --version 2>&1 | head -1; syft version 2>&1 | head -1; pip-audit --version; snyk-agent-scan --version 2>&1 | head -1; true"]
