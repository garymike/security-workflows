# security-workflows

Reusable GitHub Actions security workflows and a signed, pinned scanner **toolbox**
image — a best-in-class aggregator of upstream security tools behind a hardened,
fully pinned supply chain. Built to be reused across repos, and dogfooded here.

## Workflows

### `security-scan.yml`
Runs on every push and PR. Checks:
- Secret scanning via betterleaks (run from the pinned toolbox image)
- Unpinned action version detection
- SECURITY.md presence

### `security-audit.yml`
Runs on a schedule (weekly recommended). Checks:
- Dependabot alerts and auto-fix enabled
- Actions default permissions (should be read-only)
- Delete-branch-on-merge enabled
- Branch protection configured
- SECURITY.md present

### `gha-security.yml`
Reusable (`workflow_call`). Audits the caller's GitHub Actions workflows with the pinned `gha-toolbox` image — **zizmor** (expression/template injection, excessive permissions, unpinned actions) and **actionlint** (syntax + embedded shell via shellcheck).

### `skill-audit.yml`
Reusable (`workflow_call`). Reviews agent skills with the pinned `skill-audit-toolbox` — **SkillSpector** (agent-execution surface: prompt injection, tool poisoning, exfiltration) plus a first-party **test-file gate** for the developer-execution surface no published skill scanner covers. See [`docs/threat-model.md`](docs/threat-model.md).

## Usage

Add a `.github/workflows/security.yml` to each repo, pinned to a release tag (or a
commit SHA for maximum safety — see [ADR-0008](docs/adr/0008-versioning.md)):

```yaml
name: Security

on:
  push:
    branches: ["**"]
  pull_request:
  schedule:
    - cron: '0 8 * * 1'
  workflow_dispatch:

jobs:
  scan:
    permissions:
      contents: read
      packages: read      # pull the pinned scanner image from GHCR
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@v0.3.0
    secrets: inherit

  audit:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    permissions:
      contents: read
    uses: garymike/security-workflows/.github/workflows/security-audit.yml@v0.3.0
    secrets: inherit
```

Optional extra audits (same pinning): `gha-security.yml` (zizmor + actionlint) and
`skill-audit.yml` (SkillSpector + test-file gate; needs `packages: read`).

`@v0.3.0` is the current release; a moving `@v0` tag tracks the latest 0.x. This repo's
own action-pinning check treats `@vN` as unpinned, so pin to a **commit SHA** for maximum
supply-chain safety. External callers also need the GHCR scanner-image package to be
**public**.

Or use [garymike/repo-template](https://github.com/garymike/repo-template) when creating new repos — it ships with this pre-wired.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — the three planes + image layer graph.
- [`docs/adr/`](docs/adr/) — architecture decision records (0001–0009).
- [`docs/threat-model.md`](docs/threat-model.md) — skill-audit coverage map + residual gaps.
- [`docs/tool-evaluations.md`](docs/tool-evaluations.md) — tools assessed, adopted, deferred.

## Container toolbox

[`toolbox/`](toolbox/) builds **`mcp-review-toolbox`** — a pinned, cosign-signed
container image bundling the static security scanners used to review MCP servers
(betterleaks, trufflehog, osv-scanner, syft, pip-audit, snyk-agent-scan). Run it via
`docker run` anywhere, or in CI through the composite action at
[`actions/toolbox-scan`](actions/toolbox-scan). Static analysis only —
dynamic analysis (running an untrusted server, proxy interception) stays in the
caller's isolated environment. See [`toolbox/README.md`](toolbox/README.md).

- `build-toolbox.yml` — builds, SBOMs, cosign-signs, and pushes the image to GHCR
  (weekly + on change).
- `dogfood-scan.yml` — builds the image from source and scans this repo.

## Supply-chain hardening

Every third-party action in these workflows is pinned to a full commit SHA (the
trailing `# vX` comment records the human-readable version). Pinning the
reusable-workflow *call* itself — to a release tag or commit SHA rather than a
moving branch — is the recommended next step once tagged releases are published.
