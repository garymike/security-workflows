# security-workflows

Reusable GitHub Actions security workflows that run over signed, pinned scanner toolbox
images, dogfooded in this repo. It is more than an aggregator in one respect: it takes the
part of agent-skill security that scanners only warn about, the developer-execution surface,
and turns it into a CI and pre-commit gate that fails the build.

## An enforcing gate for the developer-execution surface

A malicious agent skill can ship a clean `SKILL.md` and still steal your SSH keys and CI
secrets the moment you run the project's tests. The payload rides in a bundled `*.test.ts` or
`.husky/pre-commit` file that your toolchain runs on its own (`npm test`, `git commit`), with
the agent never involved.

Scanners are starting to see this surface, but seeing it is not stopping it. SkillSpector
(v2.3 and later) reports a `.husky/` payload as a HIGH finding, yet it has no fail-on mode and
exits 0, so a CI pipeline that gates on exit codes still lets the skill through. The research
misses the surface by scope: the static state of the art
([arXiv 2601.10338](https://arxiv.org/abs/2601.10338)) scans "`SKILL.md` plus the scripts the
skill may invoke", and the dynamic state of the art
([arXiv 2607.02357](https://arxiv.org/abs/2607.02357)) detonates the agent, not `npm test`.
The first-party [`skill-testfile-gate`](toolbox/skill-audit/skill-testfile-gate.sh) in
[`skill-audit.yml`](.github/workflows/skill-audit.yml) is built for this surface. It fails the
build (exit 1) on malice, is layered so it does not fire on honest test files, emits SARIF, and
runs as a pre-commit hook. A CI proof-fixture re-checks the enforce-versus-advise gap on every
build.

Read next: [the Gecko-vector walkthrough](docs/gecko-vector-walkthrough.md), the
[coverage map](docs/threat-model.md), and [the proof-fixture](tests/gate-proof.sh).

Everything below is the supporting layer: established upstream tools behind a digest-pinned,
signed, and attested supply chain.

## Workflows

### `security-scan.yml`
Runs on every push and PR. Checks:
- Secret scanning via betterleaks (run from the pinned toolbox image)
- Unpinned action version detection
- SECURITY.md presence

### `security-audit.yml`
Runs on a schedule (weekly is a sensible default). Checks:
- Dependabot alerts and auto-fix enabled
- Actions default permissions (should be read-only)
- Delete-branch-on-merge enabled
- Branch protection configured
- SECURITY.md present

### `gha-security.yml`
Reusable (`workflow_call`). Audits the caller's GitHub Actions workflows with the pinned
`gha-toolbox` image: zizmor (expression and template injection, excessive permissions, unpinned
actions) and actionlint (syntax plus embedded shell via shellcheck).

### `skill-audit.yml`
Reusable (`workflow_call`). Reviews agent skills with the pinned `skill-audit-toolbox`:
SkillSpector for the agent-execution surface (prompt injection, tool poisoning, exfiltration),
plus the first-party `skill-testfile-gate` for the developer-execution surface that no published
scanner covers. The gate has two layers, presence (an inventory of what is there) and malice (a
Semgrep rule pack that blocks and emits SARIF), across test files, git hooks, and lifecycle
scripts. See the [walkthrough](docs/gecko-vector-walkthrough.md) and
[threat model](docs/threat-model.md). Callers must grant `security-events: write`.

### `sast.yml`
Reusable (`workflow_call`). Static application security testing with the pinned `sast-toolbox`
(Semgrep OSS); emits SARIF to code scanning. Portable across public and private repos.

### `codeql.yml`
Reusable (`workflow_call`). Deep whole-program SAST via CodeQL, the complementary engine for
public repos. Most public repos are better served by GitHub's code-scanning default setup; use
this for a centralized or advanced setup across repos.

### `ai-review.yml`
Reusable (`workflow_call`), an optional AI-semantic layer. Wraps the official
[anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review)
action: Claude reviews the PR diff for injection, authorization, crypto, RCE, and business-logic
flaws, with a second LLM pass to filter false positives. It complements the static engines above
rather than duplicating them. Anthropic maintains the engine; this repo pins it by SHA. It is
opt-in: it needs a `claude-api-key` secret (per-run cost) and, per Anthropic, is not hardened
against prompt injection, so require approval for external contributors. See
[tool-evaluations](docs/tool-evaluations.md).

### `iac-security.yml`
Reusable (`workflow_call`). Infrastructure-as-Code and misconfiguration scanning with the pinned
`iac-toolbox` (Checkov): Terraform, Dockerfiles, Kubernetes, Helm, and CloudFormation; emits
SARIF to code scanning.

## Usage

Add a `.github/workflows/security.yml` to each repo, pinned to a release tag (or a
commit SHA for maximum safety, see [ADR-0008](docs/adr/0008-versioning.md)):

```yaml
name: Security

on:
  # Scan pushes to the default branch and every PR. Feature-branch pushes are
  # already covered by their PR, so scanning every branch push too
  # (branches: ["**"]) double-bills Actions minutes on private repos. Public
  # repos have free Actions and may broaden to branches: ["**"] if they want
  # direct-push coverage on branches that never open a PR.
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 8 * * 1'
  workflow_dispatch:

# Cancel superseded runs on the same ref (rapid pushes / PR updates).
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  scan:
    permissions:
      contents: read
      packages: read      # pull the pinned scanner image from GHCR
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@v1.4.0
    secrets: inherit

  audit:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    permissions:
      contents: read
    uses: garymike/security-workflows/.github/workflows/security-audit.yml@v1.4.0
    secrets: inherit
```

Optional extra audits (same pinning): `gha-security.yml` (zizmor plus actionlint),
`skill-audit.yml` (SkillSpector plus the test-file gate; needs `packages: read`), and
`ai-review.yml` (AI-semantic PR review via Claude; needs a `claude-api-key` secret).

`@v1.4.0` is the current release; a moving `@v1` tag tracks the latest 1.x. This repo's
own action-pinning check treats `@vN` as unpinned, so pin to a commit SHA for maximum
supply-chain safety. The scanner images are published publicly on GHCR, so any caller
can pull them.

Or use [garymike/repo-template](https://github.com/garymike/repo-template) when creating new
repos; it ships with this pre-wired.

## Shift-left: catch it before `npm test`

CI is often too late for the developer-execution vector. A malicious skill detonates on your
machine the moment you run the tests, before anything reaches a PR. Run the gate locally as a
[pre-commit](https://pre-commit.com) hook:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/garymike/security-workflows
    rev: v1.4.0
    hooks:
      - id: skill-testfile-gate
```

Install it on the stages that matter: at commit, and, most importantly, when a skill arrives via
a pull, before you would run its tests:

```bash
pre-commit install --hook-type pre-commit --hook-type post-merge --hook-type post-checkout
```

It runs the pinned, signed `skill-audit-toolbox` image and blocks on malice. That is the same
image CI uses, so there is one cryptographic source of truth. No Docker Desktop? The
`skill-testfile-gate-any` hook (and [`bin/skill-gate`](bin/skill-gate)) run the identical gate
via Podman or WSL Containers (`wslc`), and the image runs offline once sideloaded. See the
[local-runner guide](docs/local-runner.md).

Residual risk, stated plainly: a git-stage hook catches a skill that arrives through git. It
does not catch one you download outside git (curl, a marketplace installer); that still needs
review-before-install and keeping `.claude`, `.cursor`, and `.agents` out of your test-runner
globs (see the [threat model](docs/threat-model.md)). This closes the git-borne path and
documents the rest.

## Documentation

- [`docs/architecture.md`](docs/architecture.md): the three planes plus the image-layer graph.
- [`docs/gecko-vector-walkthrough.md`](docs/gecko-vector-walkthrough.md): the developer-execution-surface exploit, end to end (defanged).
- [`docs/adr/`](docs/adr/): architecture decision records (0001 to 0012).
- [`docs/threat-model.md`](docs/threat-model.md): the skill-audit coverage map and residual gaps.
- [`docs/references.md`](docs/references.md): the canonical bibliography for the research and incidents cited.
- [`docs/tool-evaluations.md`](docs/tool-evaluations.md): tools assessed, adopted, and deferred.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): local builds, the signed-commit and PR flow, and releases.

## Container toolbox

[`toolbox/`](toolbox/) builds a layered set of signed images: a shared `security-toolbox-base`
(betterleaks, trufflehog, osv-scanner, syft) plus the domain images `mcp-review-toolbox`,
`gha-toolbox`, and `skill-audit-toolbox` that build `FROM` it by digest. Run them via
`docker run` anywhere, in CI through the composite action at
[`actions/toolbox-scan`](actions/toolbox-scan), or via the reusable workflows above. These are
static analysis only; dynamic analysis (running an untrusted server or skill, proxy interception)
stays in the caller's isolated environment. See [`toolbox/README.md`](toolbox/README.md).

- `build-toolbox.yml` builds each image, attaches an SBOM and provenance, gates on fixable
  CRITICAL CVEs with Trivy, signs with cosign, and pushes to GHCR (weekly and on change).
- `dogfood-scan.yml` builds the whole stack from source and scans this repo.

## Supply-chain hardening

Every third-party action in these workflows is pinned to a full commit SHA (the trailing
`# vX` comment records the human-readable version), and every published toolbox image is
SBOM'd, provenance-attested, Trivy-gated, and cosign-signed. Tagged
[releases](https://github.com/garymike/security-workflows/releases) are published, so pin
the reusable-workflow call to a release tag, or a commit SHA for maximum safety (this
repo's own check treats `@vN` as unpinned). See [ADR-0008](docs/adr/0008-versioning.md).
