# security-workflows

Reusable GitHub Actions security workflows over signed, pinned scanner **toolbox images**,
dogfooded here. What makes it more than an aggregator: it turns the one part of agent-skill
security that scanners only *advise* on — the **developer-execution surface** — into an enforcing
CI/pre-commit **gate**.

## The differentiator: an enforcing gate for the developer-execution surface

A malicious agent skill can ship a **clean `SKILL.md`** and still steal your SSH keys and CI secrets the
moment you run the project's tests — because the payload rides in a bundled `*.test.ts` or `.husky/pre-commit`
that your *toolchain* auto-executes (`npm test`, `git commit`), entirely outside the agent.

Scanners are catching up to *seeing* this surface, but they don't **stop** it. SkillSpector (v2.3+) reports a
`.husky/` payload as a HIGH finding — yet it has no fail-on mode, so it **exits 0**, and a CI pipeline gating on
exit codes lets the skill through. And the research state-of-the-art misses the surface *by scope*: the static
SOTA ([arXiv 2601.10338](https://arxiv.org/abs/2601.10338)) scans "`SKILL.md` + scripts the skill *may invoke*";
the dynamic SOTA ([arXiv 2607.02357](https://arxiv.org/abs/2607.02357)) detonates the *agent*, not `npm test`.
[`skill-audit.yml`](.github/workflows/skill-audit.yml)'s first-party
**[`skill-testfile-gate`](toolbox/skill-audit/skill-testfile-gate.sh)** is the purpose-built *enforcing* gate for
exactly this surface — it **fails the build** (exit 1) on malice, layered so it doesn't cry wolf on honest tests,
emits SARIF, and runs as a pre-commit hook — and a **CI proof-fixture** re-proves the enforce-vs-advise gap on
every build.

→ **[The Gecko-vector walkthrough](docs/gecko-vector-walkthrough.md)** · [coverage map](docs/threat-model.md) · [the proof-fixture](tests/gate-proof.sh)

Everything below is the **credibility layer**: best-in-class upstream tools behind a hardened,
digest-pinned, signed, and attested supply chain.

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
Reusable (`workflow_call`). Reviews agent skills with the pinned `skill-audit-toolbox` — **SkillSpector** (agent-execution surface: prompt injection, tool poisoning, exfiltration) plus the first-party **`skill-testfile-gate`** for the **developer-execution surface** no published scanner covers: layered *presence* (inventory) vs. *malice* (a Semgrep rule pack that blocks and emits SARIF), across test files, git hooks, and lifecycle scripts. See the [walkthrough](docs/gecko-vector-walkthrough.md) and [threat model](docs/threat-model.md). Callers must grant `security-events: write`.

### `sast.yml`
Reusable (`workflow_call`). Static application security testing with the pinned `sast-toolbox` (**Semgrep** OSS); emits SARIF to code scanning. Universal/portable — public *and* private repos.

### `codeql.yml`
Reusable (`workflow_call`). Deep whole-program SAST via **CodeQL** — the complementary engine for public repos. Most public repos are better served by GitHub's code-scanning **default setup**; use this for centralized/advanced setup across repos.

### `iac-security.yml`
Reusable (`workflow_call`). Infrastructure-as-Code / misconfiguration scanning with the pinned `iac-toolbox` (**Checkov**) — Terraform, Dockerfiles, K8s, Helm, CloudFormation; emits SARIF to code scanning.

## Usage

Add a `.github/workflows/security.yml` to each repo, pinned to a release tag (or a
commit SHA for maximum safety — see [ADR-0008](docs/adr/0008-versioning.md)):

```yaml
name: Security

on:
  # Scan pushes to the default branch + every PR. Feature-branch pushes are
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
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@v1.3.0
    secrets: inherit

  audit:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    permissions:
      contents: read
    uses: garymike/security-workflows/.github/workflows/security-audit.yml@v1.3.0
    secrets: inherit
```

Optional extra audits (same pinning): `gha-security.yml` (zizmor + actionlint) and
`skill-audit.yml` (SkillSpector + test-file gate; needs `packages: read`).

`@v1.3.0` is the current release; a moving `@v1` tag tracks the latest 1.x. This repo's
own action-pinning check treats `@vN` as unpinned, so pin to a **commit SHA** for maximum
supply-chain safety. The scanner images are published **publicly** on GHCR, so any caller
can pull them.

Or use [garymike/repo-template](https://github.com/garymike/repo-template) when creating new repos — it ships with this pre-wired.

## Shift-left: catch it before `npm test`

CI is often too late for the developer-execution vector — a malicious skill detonates on your
machine the moment you run the tests, before anything reaches a PR. Run the gate locally as a
[pre-commit](https://pre-commit.com) hook:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/garymike/security-workflows
    rev: v1.2.0
    hooks:
      - id: skill-testfile-gate
```

Install it on the stages that matter — at commit, and (crucially) **when a skill arrives via a
pull**, before you'd run its tests:

```bash
pre-commit install --hook-type pre-commit --hook-type post-merge --hook-type post-checkout
```

It runs the pinned, signed `skill-audit-toolbox` image and blocks on malice — the **same image as
CI**, one cryptographic source of truth. **No Docker Desktop?** The `skill-testfile-gate-any` hook
(and [`bin/skill-gate`](bin/skill-gate)) run the identical gate via Podman or **WSL Containers
(`wslc`)**, and the image runs **offline / air-gapped** once sideloaded — see the
[local-runner guide](docs/local-runner.md).

**Honest residual:** a git-stage hook catches a skill that arrives *through git*. It does **not**
catch one you download outside git (curl, a marketplace installer) — that still needs
review-before-install and excluding `.claude`/`.cursor`/`.agents` from your test-runner globs
(see the [threat model](docs/threat-model.md)). We close the git-borne path and document the rest.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — the three planes + image layer graph.
- [`docs/gecko-vector-walkthrough.md`](docs/gecko-vector-walkthrough.md) — the developer-execution-surface exploit, end to end (defanged).
- [`docs/adr/`](docs/adr/) — architecture decision records (0001–0012).
- [`docs/threat-model.md`](docs/threat-model.md) — skill-audit coverage map + residual gaps.
- [`docs/references.md`](docs/references.md) — canonical bibliography for the research + incidents cited.
- [`docs/tool-evaluations.md`](docs/tool-evaluations.md) — tools assessed, adopted, deferred.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local builds, the signed-commit/PR flow, and releases.

## Container toolbox

[`toolbox/`](toolbox/) builds a **layered set of signed images** — a shared
`security-toolbox-base` (betterleaks, trufflehog, osv-scanner, syft) plus the domain images
`mcp-review-toolbox`, `gha-toolbox`, and `skill-audit-toolbox` that build `FROM` it by
digest. Run them via `docker run` anywhere, in CI through the composite action at
[`actions/toolbox-scan`](actions/toolbox-scan), or via the reusable workflows above. Static
analysis only — dynamic analysis (running an untrusted server or skill, proxy interception)
stays in the caller's isolated environment. See [`toolbox/README.md`](toolbox/README.md).

- `build-toolbox.yml` — builds each image, attaches an SBOM + provenance, **Trivy-gates** on
  fixable CRITICAL CVEs, cosign-signs, and pushes to GHCR (weekly + on change).
- `dogfood-scan.yml` — builds the whole stack from source and scans this repo.

## Supply-chain hardening

Every third-party action in these workflows is pinned to a full commit SHA (the trailing
`# vX` comment records the human-readable version), and every published toolbox image is
SBOM'd, provenance-attested, Trivy-gated, and cosign-signed. Tagged
[releases](https://github.com/garymike/security-workflows/releases) are published, so pin
the reusable-workflow *call* to a release tag — or a commit SHA for maximum safety (this
repo's own check treats `@vN` as unpinned). See [ADR-0008](docs/adr/0008-versioning.md).
