# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# skill-audit-toolbox — Anthropic Skill / agent-capability security review, layered on
# the signed base.
#   = base + SkillSpector (agent-execution surface: prompt injection, tool poisoning,
#     data exfil, excessive agency) + a first-party test-file gate for the DEVELOPER-
#     execution surface that no published skill scanner covers.
# STATIC ANALYSIS ONLY. See docs/threat-model.md for the coverage map + residual gaps.
#
# BASE is pinned by digest in CI. SkillSpector ships no PyPI release or tags, so it is
# pinned by commit SHA (installs its own semgrep/langgraph deps). Keep the pins in sync
# with toolbox/tools.lock.

ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest
FROM ${BASE}

# NVIDIA/SkillSpector, pinned by commit (no releases upstream).
ARG SKILLSPECTOR_REF=c2d09df019e358d3dc12d980b82c798b87cb9f56

LABEL org.opencontainers.image.title="skill-audit-toolbox" \
      org.opencontainers.image.description="Anthropic Skill / agent-capability security review — security-toolbox-base + SkillSpector + a developer-execution-surface (test-file) gate." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

# SkillSpector from source (git present in base); installs semgrep + langgraph deps.
USER root
RUN set -eux; \
    pip install --no-cache-dir "git+https://github.com/NVIDIA/SkillSpector@${SKILLSPECTOR_REF}"
COPY skill-testfile-gate.sh /usr/local/bin/skill-testfile-gate
RUN chmod 0755 /usr/local/bin/skill-testfile-gate
USER toolbox

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'skill-audit-toolbox — pinned skill-review tools:'; skillspector --version 2>&1 | head -1; skillspector --help >/dev/null 2>&1 && echo 'skillspector: ok'; echo -n 'skill-testfile-gate: '; command -v skill-testfile-gate; true"]
