# security-workflows

Reusable GitHub Actions security workflows over signed, pinned scanner toolbox images,
dogfooded in this repo.

It is the static layer of a small security platform with one throughline: most AI-native
security tooling stops at advice (it scans, reports, and exits 0), and this platform turns that
advice into a control that blocks. Here, at build time, auto-run repo artifacts (a skill's test
files and git hooks, and the agent's own `.claude` and `.mcp.json` config) are scanned and the
build fails on malice. At runtime, in [security-agents](https://github.com/garymike/security-agents),
an MCP server review is compiled into a firewall policy that blocks unapproved egress and tool
calls. The reviews come from the methodology skills in
[garymike/skills](https://github.com/garymike/skills). Assess in the skills, enforce here and in
security-agents.

How it is built is part of the point: adopt best-in-class tools where they exist (pinned and
signed, never forked), build first-party only where the field has a real gap, and keep it modular
(engine-neutral contracts, swappable adapters, composable workflows) so a new tool slots in
without moving the story.

## Where this is ahead of the field

A malicious agent skill can ship a clean `SKILL.md` and still steal your SSH keys the moment you
run the project's tests, because the payload rides in a bundled test file or git hook that your
toolchain auto-runs, outside the agent. Scanners see it and exit 0. The first-party
[`skill-testfile-gate`](toolbox/skill-audit/skill-testfile-gate.sh) fails the build instead. The
same gate now covers auto-run agent config across Claude Code (`.claude/settings.json` Hooks,
`.mcp.json` servers, CVE-2025-59536), Cursor (`.cursor/mcp.json`, CVE-2025-54136; `.cursor/hooks.json`
by structural analogy), and VS Code (`.vscode/tasks.json` run silently on open, a disclosed and
now-fixed security issue): the config-injection class. The runtime pillar, an MCP review compiled
into a firewall, is the assess-to-enforce gateway in
[security-agents](https://github.com/garymike/security-agents).

Each of these is a worked example with a runnable defanged demo and the CI proof that re-checks it
on every build. See the **[threat profiles](docs/threats/)**.

---

## Questions to ask before you adopt this

The rest of this README is organized around what a security engineer actually asks before wiring
someone else's workflows into their CI, rather than around a catalog of what ships. If you only
read one answer, read the first.

### Does it block, or only warn?

Both, and which is which is deliberate.

**Blocks the build.** The first-party [`skill-testfile-gate`](toolbox/skill-audit/skill-testfile-gate.sh)
exits non-zero on malice, in `skill-audit.yml` and in the pre-commit hook. That is the whole point
of the project: the surface it covers is one where the published scanners report and exit 0, so a
CI gate on exit codes lets the payload through. It also fails on the config-injection class
(`.claude/settings.json` Hooks, `.mcp.json`, `.cursor/`, `.vscode/tasks.json`).

**Reports to code scanning.** `sast.yml`, `codeql.yml`, and `iac-security.yml` emit SARIF and let
you decide the gate, because a blanket fail-on-any-finding is how teams learn to ignore a scanner.
Set your own thresholds in GitHub's code-scanning configuration.

**Reports, and you choose.** `ai-review.yml` exposes a `findings-count` output so a calling job can
fail when it is greater than zero. `security-scan.yml` takes a `fail-on-findings` input.

The distinction matters more than it looks: everything that blocks by default is a surface with a
documented gap and a CI proof fixture behind it. Everything else defers to you, because it is
scanning a surface where the field already has good judgment and you have context this repo does not.

### What actually runs, and does my code leave the runner?

Static analysis in a container, on the runner, with no egress required by the scanners themselves.
The scanners run from digest-pinned toolbox images pulled from GHCR; your source is bind-mounted in
and the findings come back out as SARIF.

Two honest exceptions. `codeql.yml` uploads results to GitHub code scanning, which is the point of
it. `ai-review.yml` sends the PR diff to Anthropic's API, which is why it is opt-in, needs a
`claude-api-key` secret, and carries a per-run cost.

Dynamic analysis, meaning actually running an untrusted skill or MCP server, is deliberately not
here. It lives in [security-agents](https://github.com/garymike/security-agents) inside the caller's
own isolation, because isolation is a property of the deployment and not of the tool.

### How do I know the toolbox images have not been tampered with?

Every published image is SBOM'd, provenance-attested, gated on fixable CRITICAL CVEs by Trivy, and
cosign-signed before it is pushed. [`toolbox/`](toolbox/) builds them as a layered set: a shared
`security-toolbox-base` (betterleaks, trufflehog, osv-scanner, syft) plus the domain images
`mcp-review-toolbox`, `gha-toolbox`, `skill-audit-toolbox`, `sast-toolbox`, and `iac-toolbox` that
build `FROM` it by digest.

Every third-party action in these workflows is pinned to a full commit SHA, with a trailing `# vX`
comment recording the human-readable version. Pin your call to a release tag, or to a commit SHA
for maximum safety: this repo's own action-pinning check treats `@vN` as unpinned, which is the
honest position. See [ADR-0008](docs/adr/0008-versioning.md).

`build-toolbox.yml` runs the build weekly and on change. `dogfood-scan.yml` builds the whole stack
from source and scans this repo with it, so the images are exercised by their own maintainer before
anyone else pulls them.

### What will it cost in CI time?

Measured on this repo's own self-scan, each job in its own runner:

| Job | Duration |
|---|---|
| `security-audit` (repo settings) | 9s |
| `security-scan` (secrets) | 12s |
| `gha-security` (zizmor + actionlint) | 15s |
| `skill-audit` (SkillSpector + gate) | 25s |
| `sast` (Semgrep) | 30s |
| `iac-security` (Checkov) | 35s |

They run as parallel jobs, so wall clock is the longest one rather than the sum. Treat these as a
floor, not a promise: this repo is small, and the numbers scale with your codebase. `codeql.yml` is
the long pole wherever it is enabled and is usually better served by GitHub's default setup.
`ai-review.yml` adds per-run API cost on top of time.

The usage snippet below sets `concurrency` with `cancel-in-progress`, so rapid pushes cancel
superseded runs instead of double-billing.

### Can I run it on my own machine, without Docker, or offline?

Yes to all three. [`bin/skill-gate`](bin/skill-gate) runs the identical gate on whatever OCI runtime
you have, auto-selecting Docker, then Podman, then WSL Containers (`wslc`), each health-checked
because installed is not the same as running. The image runs offline once sideloaded.

That matters because CI is often too late for this particular vector: a malicious skill detonates
when you run the tests, before anything reaches a PR. Install the gate on the stages that catch it,
especially when a skill arrives via a pull:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/garymike/security-workflows
    rev: v1.6.0
    hooks:
      - id: skill-testfile-gate
```

```bash
pre-commit install --hook-type pre-commit --hook-type post-merge --hook-type post-checkout
```

It runs the same pinned, signed `skill-audit-toolbox` image CI uses, so there is one cryptographic
source of truth. Without Docker Desktop, use the `skill-testfile-gate-any` hook. See the
[local-runner guide](docs/local-runner.md).

### What is adopted, what is first-party, and what happens when upstream changes?

| | What | Why |
|---|---|---|
| **Adopted** (best-in-class, pinned and signed) | Semgrep, CodeQL, Checkov, betterleaks, trufflehog, SkillSpector, Anthropic's AI review, plus pipelock and OPA in security-agents | Do not reinvent a solved problem. Each is pinned by digest or SHA, SBOM'd, and cosign-signed. |
| **First-party** (only where the field has a gap) | the enforcing gate for the developer-execution and config-injection surface (this repo); the assess-to-enforce compiler and engine-neutral policy contract (security-agents) | Build where the field only advises. |
| **Modular** (the mechanism) | the `mcp-runtime-policy` contract with swappable adapters, layered signed images, composable reusable workflows | So the two rows above can evolve while the story does not. |

When an upstream tool grows to cover a first-party gap, the first-party code is meant to be retired
rather than defended. That sunset rule is recorded in
[ADR-0004](docs/adr/0004-aggregator-not-a-fork.md), and
[`docs/tool-evaluations.md`](docs/tool-evaluations.md) is the running ledger of what was assessed,
adopted, deferred, and why.

### What does it deliberately not cover?

Stated plainly, because a security tool that hides its edges is worse than one that has them.

- **Downloads outside git.** A git-stage hook catches a skill that arrives through git. It does not
  catch one you `curl` or install from a marketplace. That still needs review-before-install, and
  keeping `.claude`, `.cursor`, and `.agents` out of your test-runner globs.
- **Anything dynamic.** Nothing here executes an untrusted skill or server. That is
  [security-agents](https://github.com/garymike/security-agents), in your isolation.
- **Packed or obfuscated payloads.** The static gate flags opaque artifacts as candidates and
  escalates them; it does not claim to read them.
- **`ai-review.yml` is not hardened against prompt injection**, per Anthropic. Require approval for
  external contributors before running it on their PRs.

The [threat model](docs/threat-model.md) is the full coverage map with residual gaps.

### How do I adopt it incrementally?

Start with the two that need no configuration, then add the reusable ones you want. Add a
`.github/workflows/security.yml`, pinned to a release tag (or a commit SHA for maximum safety):

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
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@v1.6.0
    secrets: inherit

  audit:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    permissions:
      contents: read
    uses: garymike/security-workflows/.github/workflows/security-audit.yml@v1.6.0
    secrets: inherit
```

`@v1.6.0` is the current release; a moving `@v1` tag tracks the latest 1.x. The scanner images are
published publicly on GHCR, so any caller can pull them.

Or use [garymike/repo-template](https://github.com/garymike/repo-template) when creating new repos;
it ships with this pre-wired.

---

## Workflow reference

| Workflow | Call style | What it does | Notes |
|---|---|---|---|
| `security-scan.yml` | push / PR | Secret scanning (betterleaks from the pinned image), unpinned-action detection, SECURITY.md presence | `fail-on-findings` input |
| `security-audit.yml` | schedule | Repo settings: Dependabot alerts and auto-fix, Actions default permissions, delete-branch-on-merge, branch protection, SECURITY.md | Weekly is a sensible default |
| `gha-security.yml` | `workflow_call` | Audits the caller's Actions workflows with `gha-toolbox`: zizmor (expression and template injection, excessive permissions, unpinned actions) plus actionlint (syntax and embedded shell via shellcheck) | |
| `skill-audit.yml` | `workflow_call` | SkillSpector for the agent-execution surface, plus the first-party `skill-testfile-gate` for the developer-execution and config-injection surfaces. Two layers: presence (inventory) and malice (a Semgrep rule pack that blocks and emits SARIF) | **Blocks.** Needs `security-events: write` and `packages: read`. See the [walkthrough](docs/gecko-vector-walkthrough.md) |
| `sast.yml` | `workflow_call` | Semgrep OSS from `sast-toolbox`; SARIF to code scanning. Portable across public and private repos | |
| `codeql.yml` | `workflow_call` | Deep whole-program SAST. Most public repos are better served by GitHub's default setup; use this for a centralized or advanced setup | |
| `iac-security.yml` | `workflow_call` | Checkov from `iac-toolbox`: Terraform, Dockerfiles, Kubernetes, Helm, CloudFormation; SARIF to code scanning | |
| `ai-review.yml` | `workflow_call` | Wraps the official [anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review): Claude reviews the PR diff for injection, authorization, crypto, RCE, and business-logic flaws, with a second LLM pass to filter false positives | Opt-in. Needs `claude-api-key`. `findings-count` output, plus passthrough for model, excluded dirs, timeout, and custom instructions. Also available in Claude Code as `/security-review` |

The toolbox images are runnable outside CI too: `docker run` them directly, or use the composite
action at [`actions/toolbox-scan`](actions/toolbox-scan). See [`toolbox/README.md`](toolbox/README.md).

## Documentation

- [`docs/threats/`](docs/threats/): the proving ground, one profile per real attack (threat, defanged demo, defense, and CI proof).
- [`docs/architecture.md`](docs/architecture.md): the three planes plus the image-layer graph.
- [`docs/gecko-vector-walkthrough.md`](docs/gecko-vector-walkthrough.md): the developer-execution-surface exploit, end to end (defanged).
- [`docs/adr/`](docs/adr/): architecture decision records (0001 to 0014).
- [`docs/threat-model.md`](docs/threat-model.md): the skill-audit coverage map and residual gaps.
- [`docs/references.md`](docs/references.md): the canonical bibliography for the research and incidents cited.
- [`docs/tool-evaluations.md`](docs/tool-evaluations.md): tools assessed, adopted, and deferred.
- [`docs/local-runner.md`](docs/local-runner.md): running the gate on Docker, Podman, or WSL Containers.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): local builds, the signed-commit and PR flow, and releases.
