# Toolbox images

A layered set of pinned, cosign-signed container images bundling the **static** security
scanners this repo runs. Use them via `docker run …` locally, in any CI, through the
reusable workflows, or via the `toolbox-scan` composite action — so the scanners never have
to be installed on an analyst's machine, and every run uses the same pinned versions.

**Static analysis only.** Reading files, definitions, and dependencies is safe to run
anywhere. Dynamic analysis — actually running an untrusted MCP server or skill, or
intercepting its traffic — is deliberately *not* here; it stays in the caller's own
isolated sandbox and is never centralized.

## Image layers

A shared, separately-published base carries the generic scanners; each domain image builds
`FROM` it, pinned by **digest**, and adds only what is domain-specific:

```
security-toolbox-base    ← betterleaks · trufflehog · osv-scanner · syft (generic spine)
  ├── mcp-review-toolbox  ← + pip-audit · snyk-agent-scan
  ├── gha-toolbox         ← + zizmor · actionlint (+ shellcheck)
  ├── skill-audit-toolbox ← + SkillSpector · skill-testfile-gate
  └── sast-toolbox        ← + Semgrep
```

## Bundled tools

| Image | Tool | Purpose |
|---|---|---|
| **base** (shared) | betterleaks | secret scanning (drop-in gitleaks successor) |
| | trufflehog | verified-secret scanning |
| | osv-scanner | dependency CVEs |
| | syft | SBOM generation (SPDX/CycloneDX) |
| **mcp-review-toolbox** | pip-audit | Python dependency audit |
| | snyk-agent-scan | MCP tool-surface scan (renamed from Invariant Labs `mcp-scan`) |
| **gha-toolbox** | zizmor | GitHub Actions security (expression/template injection, perms, unpinned actions) |
| | actionlint (+ shellcheck) | workflow syntax + embedded shell |
| **skill-audit-toolbox** | SkillSpector | agent-skill scanner (prompt injection, tool poisoning, exfiltration) |
| | skill-testfile-gate | first-party gate for the developer-execution surface no scanner covers |
| **sast-toolbox** | Semgrep | static application security testing (general code + LLM rulesets via `--config`) |

Exact versions (and the SkillSpector commit pin) are in [`tools.lock`](tools.lock) and the
Dockerfile ARGs.

## Build locally

```bash
# base first, then any domain image FROM the local base
docker build -t security-toolbox-base:ci ./toolbox/base
docker build --build-arg BASE=security-toolbox-base:ci -t mcp-review-toolbox:ci   ./toolbox/mcp-review
docker build --build-arg BASE=security-toolbox-base:ci -t gha-toolbox:ci          ./toolbox/gha
docker build --build-arg BASE=security-toolbox-base:ci -t skill-audit-toolbox:ci  ./toolbox/skill-audit
```

## Run it

```bash
IMAGE=ghcr.io/garymike/security-workflows/mcp-review-toolbox:latest   # pin by digest in real use

# Secret scan a checkout (filesystem mode; use `betterleaks git` for history)
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" betterleaks dir /src --no-banner --redact
# Dependency vulnerabilities
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" osv-scanner scan --recursive /src
# SBOM
docker run --rm -v "$PWD:/src:ro" -w /src "$IMAGE" syft dir:/src -o spdx-json > sbom.spdx.json

# GitHub Actions security (gha-toolbox)
docker run --rm -v "$PWD:/src:ro" -w /src \
  ghcr.io/garymike/security-workflows/gha-toolbox:latest actionlint -color

# Skill review (skill-audit-toolbox): the developer-execution-surface gate + SkillSpector
docker run --rm -v "$PWD:/src:ro" -w /src \
  ghcr.io/garymike/security-workflows/skill-audit-toolbox:latest skill-testfile-gate /src
```

Or in a workflow, via the reusable workflows (`security-scan`, `gha-security`,
`skill-audit`) or the composite action:

```yaml
- uses: garymike/security-workflows/actions/toolbox-scan@<sha>
  with:
    path: .
    scanners: betterleaks,osv-scanner,syft
    fail-on-findings: 'true'
```

## Supply chain

- **Base OS image** pinned by digest; `security-toolbox-base` is itself a signed, SBOM'd
  image that each domain image pins by digest.
- **Go tools** pinned by version, verified against their release-published SHA-256 checksums
  at build time; **Python tools** pinned to exact PyPI versions (SkillSpector by commit SHA).
- **Every published image** is built in CI with an attached **SBOM** and **provenance**
  (`mode=max`), **Trivy-gated** on fixable CRITICAL CVEs before publish, and **cosign-signed**
  (keyless, Sigstore/OIDC). Verify before use (any image):

  ```bash
  cosign verify ghcr.io/garymike/security-workflows/mcp-review-toolbox:latest \
    --certificate-identity-regexp 'https://github.com/garymike/security-workflows/.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

## Staying current

- The weekly `build-toolbox.yml` rebuilds every image (picking up base-image patches) and
  runs `scripts/check-tool-updates.sh`, which warns when a pinned tool has a newer upstream
  release.
- `dogfood-scan.yml` builds the whole stack from source and runs it against this repo on
  every push/PR — the toolbox proves itself on our own code.

## Hardening TODO (v0 → v1)

The current build verifies Go binaries against each release's *own* published checksums
(integrity, reproducible-by-version). The next step is to record out-of-band binary SHA-256
pins in `tools.lock` and have the Dockerfiles verify against them, removing trust in the
release's own checksums file.

## Relationship to the mcp-security-review skill

The `mcp-security-review` skill stays tool-agnostic. `mcp-review-toolbox` is the
fully-provisioned *fast path* at the top of its tool-availability ladder — the skill points
to it as an option but never depends on it, and falls back to manual equivalents when it
isn't available.
