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

ARG SEMGREP_VERSION=1.183.0
# PyJWT is deliberately NOT pinned here. It used to be: semgrep pinned pyjwt[crypto]~=2.13.0,
# which held PyJWT at 2.13.0 and therefore at CVE-2026-102268 (CRITICAL, fixed in 2.14.0), so
# this image installed 2.15.1 with --no-deps to defeat that constraint. As of semgrep 1.183.0
# the constraint is pyjwt[crypto]<3,>=2.15.0, so the resolver cannot reach a vulnerable version
# and an explicit pin would only drift out of step with semgrep's floor. Re-add one only if
# semgrep's lower bound ever drops below 2.14.0 again.

LABEL org.opencontainers.image.title="sast-toolbox" \
      org.opencontainers.image.description="Static application security testing — security-toolbox-base + Semgrep OSS (general code + LLM-security rulesets via --config)." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

USER root
RUN set -eux; \
    pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}"
USER toolbox

# `docker run <image>` prints the tool version as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'sast-toolbox — pinned SAST:'; semgrep --version; true"]
