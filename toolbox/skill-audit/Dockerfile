# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# skill-audit-toolbox — Anthropic Skill / agent-capability security review, layered on
# the signed base.
#   = base + SkillSpector (agent-skill scanner: prompt injection, tool poisoning, data exfil,
#     excessive agency) + a first-party test-file GATE for the DEVELOPER-execution surface.
#     SkillSpector v2.13.0 blocks most of that surface too (test-file 64/100, git-hook 76/100,
#     config-injection 100/100 and 51/100); it clears a write to persistent agent memory at 0/100.
#     The gate blocks every carrier, on the pattern rather than on a score threshold.
# STATIC ANALYSIS ONLY. See docs/threat-model.md for the coverage map + residual gaps.
#
# BASE is pinned by digest in CI. SkillSpector ships no PyPI release or tags, so it is
# pinned by commit SHA; Semgrep (the gate's malice engine) is pinned explicitly rather than
# left to SkillSpector's transitive pull. Keep the pins in sync with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

# NVIDIA/SkillSpector. No PyPI package, so it is installed from git; pinned to the
# commit a RELEASE TAG points at, not to a moving HEAD. v2.13.0 = 091a509b3d6b.
ARG SKILLSPECTOR_REF=091a509b3d6ba8ff5be528966e1f43c2e68cf214
# Semgrep drives the test-file gate's malice layer. Pinned explicitly (not left to
# SkillSpector's transitive pull) and kept in sync with sast-toolbox / toolbox/tools.lock.
ARG SEMGREP_VERSION=1.181.0
# semgrep pins pyjwt[crypto]~=2.13.0, holding PyJWT at 2.13.0 -- CVE-2026-102268,
# CRITICAL, fixed in 2.14.0. semgrep touches PyJWT only to authenticate to Semgrep
# AppSec Platform, which these workflows never do (no SEMGREP_APP_TOKEN is ever
# supplied), so the flaw is not reachable here -- but a fixable finding is fixed,
# not excepted. Installed with --no-deps so semgrep's own constraint does not pull
# 2.13.0 back; cryptography already arrives with semgrep. Drop this override once
# semgrep relaxes the pin and pip resolves 2.14.0 or later on its own.
ARG PYJWT_VERSION=2.15.1

LABEL org.opencontainers.image.title="skill-audit-toolbox" \
      org.opencontainers.image.description="Anthropic Skill / agent-capability security review — security-toolbox-base + SkillSpector + a developer-execution-surface (test-file) gate." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

# SkillSpector (from source; git present in base) + an explicitly pinned Semgrep, co-resolved
# in one pip pass so the two versions are reconciled at build time.
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends gcc python3-dev; \
    pip install --no-cache-dir \
      "git+https://github.com/NVIDIA/SkillSpector@${SKILLSPECTOR_REF}" \
      "semgrep==${SEMGREP_VERSION}"; \
    pip install --no-cache-dir --no-deps "pyjwt==${PYJWT_VERSION}"; \
    apt-get purge -y gcc python3-dev; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*
COPY skill-testfile-gate.sh /usr/local/bin/skill-testfile-gate
COPY rules/ /usr/local/share/skill-audit/
RUN chmod 0755 /usr/local/bin/skill-testfile-gate
USER toolbox

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'skill-audit-toolbox — pinned skill-review tools:'; skillspector --version 2>&1 | head -1; skillspector --help >/dev/null 2>&1 && echo 'skillspector: ok'; echo -n 'semgrep: '; semgrep --version 2>&1 | head -1; echo -n 'skill-testfile-gate: '; command -v skill-testfile-gate; echo -n 'rule pack: '; ls /usr/local/share/skill-audit/agent-exec-surface.yml 2>/dev/null || echo MISSING; true"]
