# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# mcp-review-toolbox — pinned static security scanners for reviewing MCP servers
# (and any repo). STATIC ANALYSIS ONLY. Dynamic analysis — actually running an
# untrusted MCP server, proxy/traffic interception — stays in the caller's
# isolated environment and is never centralized here.
#
# Supply chain:
#   - Base image pinned by digest.
#   - Go tools pinned by version, verified against their release-published
#     SHA-256 checksums at build time.
#   - Python tools pinned to exact PyPI versions (wheels).
# Keep the ARG versions below in sync with toolbox/tools.lock.

FROM python:3.12-slim-bookworm@sha256:8a7e7cc04fd3e2bd787f7f24e22d5d119aa590d429b50c95dfe12b3abe52f48b AS downloader

ARG GITLEAKS_VERSION=8.30.1
ARG TRUFFLEHOG_VERSION=3.95.8
ARG OSV_SCANNER_VERSION=2.4.0
ARG SYFT_VERSION=1.46.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /out

WORKDIR /tmp/dl

# gitleaks — secret scanning
RUN set -eux; \
    base="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"; \
    asset="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"; \
    curl -fsSL -o "${asset}" "${base}/${asset}"; \
    curl -fsSL -o checksums.txt "${base}/gitleaks_${GITLEAKS_VERSION}_checksums.txt"; \
    grep "${asset}$" checksums.txt | sha256sum -c -; \
    tar -xzf "${asset}" gitleaks; \
    install -m 0755 gitleaks /out/gitleaks; \
    rm -f "${asset}" checksums.txt

# trufflehog — verified-secret scanning
RUN set -eux; \
    base="https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}"; \
    asset="trufflehog_${TRUFFLEHOG_VERSION}_linux_amd64.tar.gz"; \
    curl -fsSL -o "${asset}" "${base}/${asset}"; \
    curl -fsSL -o checksums.txt "${base}/trufflehog_${TRUFFLEHOG_VERSION}_checksums.txt"; \
    grep "${asset}$" checksums.txt | sha256sum -c -; \
    tar -xzf "${asset}" trufflehog; \
    install -m 0755 trufflehog /out/trufflehog; \
    rm -f "${asset}" checksums.txt

# osv-scanner — dependency vulnerabilities (bare binary)
RUN set -eux; \
    base="https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}"; \
    asset="osv-scanner_linux_amd64"; \
    curl -fsSL -o "${asset}" "${base}/${asset}"; \
    curl -fsSL -o SHA256SUMS "${base}/osv-scanner_SHA256SUMS"; \
    grep "${asset}$" SHA256SUMS | sha256sum -c -; \
    install -m 0755 "${asset}" /out/osv-scanner; \
    rm -f "${asset}" SHA256SUMS

# syft — SBOM generation
RUN set -eux; \
    base="https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}"; \
    asset="syft_${SYFT_VERSION}_linux_amd64.tar.gz"; \
    curl -fsSL -o "${asset}" "${base}/${asset}"; \
    curl -fsSL -o checksums.txt "${base}/syft_${SYFT_VERSION}_checksums.txt"; \
    grep "${asset}$" checksums.txt | sha256sum -c -; \
    tar -xzf "${asset}" syft; \
    install -m 0755 syft /out/syft; \
    rm -f "${asset}" checksums.txt


# --------------------------------------------------------------------------- #
FROM python:3.12-slim-bookworm@sha256:8a7e7cc04fd3e2bd787f7f24e22d5d119aa590d429b50c95dfe12b3abe52f48b

# snyk-agent-scan is the renamed successor to invariantlabs-ai/mcp-scan (the
# PyPI `mcp-scan` package is now a redirect stub). Same version line (0.5.12).
ARG PIP_AUDIT_VERSION=2.10.1
ARG SNYK_AGENT_SCAN_VERSION=0.5.12

LABEL org.opencontainers.image.title="mcp-review-toolbox" \
      org.opencontainers.image.description="Pinned static security scanners for MCP server review (gitleaks, trufflehog, osv-scanner, syft, pip-audit, snyk-agent-scan)." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

# Runtime deps: ca-certificates for HTTPS (osv-scanner / trufflehog online
# checks); git so gitleaks/trufflehog can optionally scan commit history.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends git ca-certificates; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    groupadd --system toolbox; \
    useradd --system --gid toolbox --create-home --home-dir /home/toolbox toolbox

# Python static-analysis tools, pinned exact versions.
RUN set -eux; \
    pip install --no-cache-dir \
      "pip-audit==${PIP_AUDIT_VERSION}" \
      "snyk-agent-scan==${SNYK_AGENT_SCAN_VERSION}"

COPY --from=downloader /out/gitleaks /out/trufflehog /out/osv-scanner /out/syft /usr/local/bin/

USER toolbox
WORKDIR /src

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'mcp-review-toolbox — pinned scanners:'; gitleaks version; trufflehog --version 2>&1 | head -1; osv-scanner --version 2>&1 | head -1; syft version 2>&1 | head -1; pip-audit --version; snyk-agent-scan --version 2>&1 | head -1; true"]
