# mcp-review-toolbox

A pinned, signed container image bundling the **static** security scanners used
to review MCP servers (and any repo). Run it `docker run …` locally, in any CI,
or via the bundled composite Action — so the scanners don't have to be installed
on an analyst's machine, and every run uses the same pinned versions.

**Static analysis only.** Reading files, definitions, and dependencies is safe
to run anywhere. Dynamic analysis — actually running an untrusted MCP server, or
intercepting its traffic — is deliberately *not* here; it stays in the caller's
own isolated sandbox and is never centralized.

## Bundled tools

| Tool | Purpose |
|---|---|
| betterleaks | secret scanning (drop-in gitleaks successor) |
| trufflehog | verified-secret scanning |
| osv-scanner | dependency CVEs |
| syft | SBOM generation (SPDX/CycloneDX) |
| pip-audit | Python dependency audit |
| snyk-agent-scan | MCP tool-surface / agent supply-chain scan (renamed from Invariant Labs `mcp-scan`) |

Exact versions are in [`tools.lock`](tools.lock) and the Dockerfile ARGs.

## Image layers

`mcp-review-toolbox` builds on a shared, separately-published base:

```
security-toolbox-base    ← betterleaks · trufflehog · osv-scanner · syft (generic spine)
  ├── mcp-review-toolbox  ← + pip-audit · snyk-agent-scan
  └── gha-toolbox         ← + zizmor · actionlint (+ shellcheck)
```

The base is its own signed, SBOM'd image, pinned by **digest** into each domain image
at build time (`build-toolbox.yml`). Sibling domain images (gha, skill-audit) will
layer on the same base. Build the stack locally with:

```bash
docker build -t security-toolbox-base:ci ./toolbox/base
docker build --build-arg BASE=security-toolbox-base:ci -t mcp-review-toolbox:ci ./toolbox/mcp-review
```

## Use it

```bash
# Pull the published image (pin by digest in real use)
IMAGE=ghcr.io/garymike/security-workflows/mcp-review-toolbox:latest

# Secret scan a checkout (filesystem mode; use `betterleaks git` for history)
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" \
  betterleaks dir /src --no-banner --redact

# Dependency vulnerabilities
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" \
  osv-scanner scan --recursive /src

# SBOM
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" \
  syft dir:/src -o spdx-json > sbom.spdx.json
```

Or in a workflow, via the composite Action:

```yaml
- uses: garymike/security-workflows/actions/toolbox-scan@<sha>
  with:
    path: .
    scanners: betterleaks,osv-scanner,syft
    fail-on-findings: 'true'
```

## Supply chain

- **Base OS image** pinned by digest; the `security-toolbox-base` layer is itself a
  signed, SBOM'd image that each domain image pins by digest.
- **Go tools** pinned by version, verified against their release-published
  SHA-256 checksums at build time.
- **Python tools** pinned to exact PyPI versions (wheels).
- **Published images** (base and domain) are built in CI with an attached **SBOM**
  and **provenance** (`mode=max`) and **cosign-signed** (keyless, Sigstore/OIDC).
  Verify before use (same command for `security-toolbox-base`):

  ```bash
  cosign verify ghcr.io/garymike/security-workflows/mcp-review-toolbox:latest \
    --certificate-identity-regexp 'https://github.com/garymike/security-workflows/.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

## Staying current

- The weekly `build-toolbox.yml` rebuilds the image (picking up base-image
  patches) and runs `scripts/check-tool-updates.sh`, which warns when a pinned
  tool has a newer upstream release.
- `dogfood-scan.yml` builds this image from source and scans this repo on every
  push/PR — the toolbox proves itself on our own code.

## Hardening TODO (v0 → v1)

The current build verifies Go binaries against each release's *own* published
checksums (integrity, reproducible-by-version). The next step is to record
out-of-band binary SHA-256 pins in `tools.lock` and have the `Dockerfile` verify
against them, removing trust in the release's own checksums file.

## Relationship to the mcp-security-review skill

The `mcp-security-review` skill stays tool-agnostic. This image is the
fully-provisioned *fast path* at the top of its tool-availability ladder — the
skill points to it as an option but never depends on it, and falls back to
manual equivalents when it isn't available.
