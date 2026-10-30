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
# commit a RELEASE TAG points at, not to a moving HEAD. v2.13.2 = abd82935b67f.
ARG SKILLSPECTOR_REF=abd82935b67f765a9541013c0866c6349251dcdf
# Semgrep drives the test-file gate's malice layer. Pinned explicitly (not left to
# SkillSpector's transitive pull) and kept in sync with sast-toolbox / toolbox/tools.lock.
ARG SEMGREP_VERSION=1.183.0
# PyJWT is deliberately NOT pinned here. It used to be: semgrep pinned pyjwt[crypto]~=2.13.0,
# which held PyJWT at 2.13.0 and therefore at CVE-2026-102268 (CRITICAL, fixed in 2.14.0), so
# this image installed 2.15.1 with --no-deps to defeat that constraint. As of semgrep 1.183.0
# the constraint is pyjwt[crypto]<3,>=2.15.0, so the resolver cannot reach a vulnerable version
# and an explicit pin would only drift out of step with semgrep's floor. Re-add one only if
# semgrep's lower bound ever drops below 2.14.0 again.

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
