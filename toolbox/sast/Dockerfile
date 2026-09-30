# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# sast-toolbox — static application security testing, layered on the signed base.
#   = base + Semgrep OSS.
# STATIC ANALYSIS ONLY. Semgrep is the universal/portable SAST layer (public + private
# repos, off-GitHub); CodeQL (codeql.yml) is the complementary deep engine for public
# repos. See docs/adr and docs/tool-evaluations.md.
#
# BASE is pinned by digest in CI. Keep the ARG in sync with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

ARG SEMGREP_VERSION=1.178.0
# semgrep pins pyjwt[crypto]~=2.13.0, holding PyJWT at 2.13.0 -- CVE-2026-102268,
# CRITICAL, fixed in 2.14.0. semgrep touches PyJWT only to authenticate to Semgrep
# AppSec Platform, which these workflows never do (no SEMGREP_APP_TOKEN is ever
# supplied), so the flaw is not reachable here -- but a fixable finding is fixed,
# not excepted. Installed with --no-deps so semgrep's own constraint does not pull
# 2.13.0 back; cryptography already arrives with semgrep. Drop this override once
# semgrep relaxes the pin and pip resolves 2.14.0 or later on its own.
ARG PYJWT_VERSION=2.15.1

LABEL org.opencontainers.image.title="sast-toolbox" \
      org.opencontainers.image.description="Static application security testing — security-toolbox-base + Semgrep OSS (general code + LLM-security rulesets via --config)." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

USER root
RUN set -eux; \
    pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}"; \
    pip install --no-cache-dir --no-deps "pyjwt==${PYJWT_VERSION}"
USER toolbox

# `docker run <image>` prints the tool version as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'sast-toolbox — pinned SAST:'; semgrep --version; true"]
