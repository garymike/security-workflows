# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# skill-audit-toolbox — Anthropic Skill / agent-capability security review, layered on
# the signed base.
#   = base + SkillSpector (agent-skill scanner: prompt injection, tool poisoning, data exfil,
#     excessive agency — advisory, exits 0) + a first-party test-file GATE for the DEVELOPER-
#     execution surface: it fails the build (exit 1) where advisory scanners do not.
# STATIC ANALYSIS ONLY. See docs/threat-model.md for the coverage map + residual gaps.
#
# BASE is pinned by digest in CI. SkillSpector ships no PyPI release or tags, so it is
# pinned by commit SHA; Semgrep (the gate's malice engine) is pinned explicitly rather than
# left to SkillSpector's transitive pull. Keep the pins in sync with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

# NVIDIA/SkillSpector, pinned by commit (no releases upstream).
ARG SKILLSPECTOR_REF=c2d09df019e358d3dc12d980b82c798b87cb9f56
# Semgrep drives the test-file gate's malice layer. Pinned explicitly (not left to
# SkillSpector's transitive pull) and kept in sync with sast-toolbox / toolbox/tools.lock.
ARG SEMGREP_VERSION=1.168.0

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
    apt-get purge -y gcc python3-dev; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*
COPY skill-testfile-gate.sh /usr/local/bin/skill-testfile-gate
COPY rules/ /usr/local/share/skill-audit/
RUN chmod 0755 /usr/local/bin/skill-testfile-gate
USER toolbox

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'skill-audit-toolbox — pinned skill-review tools:'; skillspector --version 2>&1 | head -1; skillspector --help >/dev/null 2>&1 && echo 'skillspector: ok'; echo -n 'semgrep: '; semgrep --version 2>&1 | head -1; echo -n 'skill-testfile-gate: '; command -v skill-testfile-gate; echo -n 'rule pack: '; ls /usr/local/share/skill-audit/agent-exec-surface.yml 2>/dev/null || echo MISSING; true"]
