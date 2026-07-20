# syntax=docker/dockerfile:1
# check=skip=UndefinedVar
#
# gha-toolbox — GitHub Actions / CI-security scanners layered on security-toolbox-base.
#   = base (betterleaks, trufflehog, osv-scanner, syft) + zizmor + actionlint (+ shellcheck).
# Audits workflow files for expression/template injection, excessive permissions,
# unpinned actions, and shell/lint issues. STATIC ANALYSIS ONLY.
#
# BASE is pinned by digest in CI (build-toolbox.yml passes …@sha256:…).
# Keep the ARG versions below in sync with toolbox/tools.lock.

# BASE is a global ARG (declared before the first FROM) so the final stage can build
# FROM it; CI passes the pinned base digest. actionlint is a Go binary — fetch +
# checksum-verify it in a downloader stage first.
ARG BASE=ghcr.io/garymike/security-workflows/security-toolbox-base:latest

FROM python:3.12-slim-bookworm@sha256:8a7e7cc04fd3e2bd787f7f24e22d5d119aa590d429b50c95dfe12b3abe52f48b AS downloader

ARG ACTIONLINT_VERSION=1.7.12

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /out

WORKDIR /tmp/dl

RUN set -eux; \
    base="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}"; \
    asset="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"; \
    curl -fsSL -o "${asset}" "${base}/${asset}"; \
    curl -fsSL -o checksums.txt "${base}/actionlint_${ACTIONLINT_VERSION}_checksums.txt"; \
    grep "${asset}$" checksums.txt | sha256sum -c -; \
    tar -xzf "${asset}" actionlint; \
    install -m 0755 actionlint /out/actionlint; \
    rm -f "${asset}" checksums.txt


# --------------------------------------------------------------------------- #
FROM ${BASE}

ARG ZIZMOR_VERSION=1.26.1

LABEL org.opencontainers.image.title="gha-toolbox" \
      org.opencontainers.image.description="Pinned GitHub Actions / CI-security scanners — security-toolbox-base + zizmor + actionlint (+ shellcheck)." \
      org.opencontainers.image.source="https://github.com/garymike/security-workflows" \
      org.opencontainers.image.licenses="MIT"

# zizmor via pip (exact pin); shellcheck so actionlint can lint embedded shell.
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends shellcheck; \
    rm -rf /var/lib/apt/lists/*; \
    pip install --no-cache-dir "zizmor==${ZIZMOR_VERSION}"
COPY --from=downloader /out/actionlint /usr/local/bin/actionlint
USER toolbox

# `docker run <image>` prints tool versions as a self-test (never fails).
CMD ["sh", "-lc", "set +e; echo 'gha-toolbox — pinned GHA-security scanners:'; zizmor --version; actionlint --version; shellcheck --version 2>&1 | grep -i version | head -1; true"]
