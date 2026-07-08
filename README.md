# security-workflows

Reusable GitHub Actions security workflows and a signed, pinned scanner **toolbox**
image — a best-in-class aggregator of upstream security tools behind a hardened,
fully pinned supply chain. Built to be reused across repos, and dogfooded here.

## Workflows

### `security-scan.yml`
Runs on every push and PR. Checks:
- Secret scanning via gitleaks
- Unpinned action version detection
- SECURITY.md presence

### `security-audit.yml`
Runs on a schedule (weekly recommended). Checks:
- Dependabot alerts and auto-fix enabled
- Actions default permissions (should be read-only)
- Delete-branch-on-merge enabled
- Branch protection configured
- SECURITY.md present

## Usage

Add a `.github/workflows/security.yml` to each repo:

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
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@main
    secrets: inherit

  audit:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    uses: garymike/security-workflows/.github/workflows/security-audit.yml@main
    secrets: inherit
```

Or use [garymike/repo-template](https://github.com/garymike/repo-template) when creating new repos — it ships with this pre-wired.

## Container toolbox

[`toolbox/`](toolbox/) builds **`mcp-review-toolbox`** — a pinned, cosign-signed
container image bundling the static security scanners used to review MCP servers
(betterleaks, trufflehog, osv-scanner, syft, pip-audit, snyk-agent-scan). Run it via
`docker run` anywhere, or in CI through the composite action at
[`actions/mcp-review-toolbox`](actions/mcp-review-toolbox). Static analysis only —
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
