# security-workflows

Reusable GitHub Actions security workflows over signed, pinned scanner toolbox images,
dogfooded in this repo.

It is the static layer of a small security platform with one throughline: most AI-native
security tooling stops at assessment (it scans, scores, and recommends), and this platform turns
that assessment into a control that blocks. Here, at build time, auto-run repo artifacts (a
skill's test files and git hooks, and the agent's own `.claude` and `.mcp.json` config) are
scanned and the build fails on malice. At runtime, in [security-agents](https://github.com/garymike/security-agents),
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
toolchain auto-runs, outside the agent. That surface is what the first-party
[`skill-testfile-gate`](toolbox/skill-audit/skill-testfile-gate.sh) was built to fail the build
on, across the test-file and git-hook carriers and the config-injection class in Claude Code
(`.claude/settings.json` Hooks, `.mcp.json` servers, CVE-2025-59536), Cursor (`.cursor/mcp.json`,
CVE-2025-54136; `.cursor/hooks.json` by structural analogy) and VS Code (`.vscode/tasks.json` run
silently on open, a disclosed and now-fixed issue).

**Most of that gap has since closed, and this repo says so rather than rewording the claim.**
Measured on every build against our own fixtures ([`gate-proof.sh`](tests/gate-proof.sh) prints
the live table), SkillSpector v2.13.6 blocks four of the five: the test-file carrier (64/100), the
git-hook carrier (76/100), Claude config-injection (100/100) and the Cursor/VS Code bundle
(51/100). Two things are left, and they are narrower than what this section used to claim:

- **One carrier it still clears, and no longer because it cannot see it.** A bundled test file
  that appends to `MEMORY.md`, the agent's persistent cross-session memory, scores **27/100
  `CAUTION`, exit 0**. As of v2.13.6 the write is modelled: the report carries exactly one
  finding, `HIGH: MP3 - Memory Manipulation` at 85% confidence, with
  `carrier_kind=auto_run, destination=MEMORY.md` as its evidence. It exits 0 anyway, because 27 is
  under the `risk_score` threshold of 50. What the verdict turns on is the payload text, not the
  write: holding the mechanism fixed, the identical `appendFileSync` clears at 27/100 with an
  inert canary and blocks at 63/100 with a literal injection string, which adds two prose findings
  of its own. The inert variant is the easier one to author, because the payload only has to avoid
  reading like an injection.
- **A score threshold is not a gate.** The carrier above is the plainest case: a HIGH-severity
  finding, 85% confident, destination named in the evidence, and an exit code that installs it.
  The Cursor/VS Code bundle is the mirror image, clearing 50 by a single point, with
  `.vscode/tasks.json` contributing none of it: all 51 comes from the two `.cursor/` files, and
  the `runOn: folderOpen` + `reveal: silent` task yields zero findings. The gate blocks on a
  malice pattern in a named file and emits SARIF per finding, so it does not depend on a holistic
  score landing the right side of a line, and the payload's wording does not change its verdict.

The config-injection class is still the gate's own coverage. The runtime pillar, an MCP review compiled
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
of the project: where a published scanner reports a payload and still exits 0, a CI gate on exit
codes ships it. SkillSpector has closed most of that gap (see above); the case it still clears is
our persistent-memory-write demo, at 27/100 `CAUTION`, on a report whose single finding is a HIGH
`MP3 - Memory Manipulation` naming the destination. It also fails on the config-injection class
(`.claude/settings.json` Hooks, `.mcp.json`, `.cursor/`, `.vscode/tasks.json`).

**Reports to code scanning.** `sast.yml`, `codeql.yml`, and `iac-security.yml` emit SARIF and let
you decide the gate, because a blanket fail-on-any-finding is how teams learn to ignore a scanner.
Set your own thresholds in GitHub's code-scanning configuration. Code scanning needs Advanced
Security on a private repo, so `sast.yml` and `iac-security.yml` retain their SARIF as a run
artifact wherever that upload is off or unavailable, and put the finding count in the job summary
either way. Reporting that you
cannot read is not reporting.

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
superseded runs instead of double-billing. It also triggers on PRs and a weekly schedule but not
on push to main, because behind a PR-required ruleset that push re-scans a tree its PR just
scanned. Add `push: main` back only where direct pushes are allowed.

Three inputs trim the bill further on a private repo:

- `runner` (every reusable workflow) moves the job off GitHub-hosted runners; see the next
  question.
- `secret-scan: false` (`security-scan.yml`) skips betterleaks when the caller already gates every
  change on an equivalent scan, for example gitleaks in pre-commit plus a full-history scan in its
  own CI, reading the same `.gitleaksignore`. The action-pinning and SECURITY.md checks still run,
  and the job summary says the scan was skipped rather than reporting zero findings.
- `skip-frameworks` (`iac-security.yml`) drops Checkov frameworks that something stricter already
  covers, for example `kubernetes,helm`. The names are Checkov's own, and a wrong one fails the job.
  Checkov has no Docker Compose framework, so it cannot be skipped to defer to a compose policy.

### Can I run it on a self-hosted runner?

Yes. Every reusable workflow takes a `runner` input: a label, or a JSON array of labels.

```yaml
  scan:
    uses: garymike/security-workflows/.github/workflows/security-scan.yml@<SHA>
    with:
      runner: '["self-hosted","ci-apps"]'   # or a single label: ci-apps
```

The default is `ubuntu-latest`, and public repos should keep it: hosted runners are free there,
and a public repo's PRs can come from anyone.

**Point it only at a disposable, credential-free runner.** These jobs check out and scan PR code,
and the scanners parse that code, so a scanner bug or a hostile file runs with whatever the runner
can reach. Concretely:

- **Ephemeral**: a fresh VM or container per job (`--ephemeral` registration), so nothing one job
  leaves behind is there for the next. A long-lived runner that also builds, deploys or holds a
  cloud role turns "scan a PR" into "run a PR's input next to those credentials".
- **No standing credentials**: no cloud keys, SSH keys, kubeconfig, `.netrc` or registry logins on
  the machine. The jobs need only the `GITHUB_TOKEN` GitHub issues per run, plus outbound HTTPS to
  GitHub (`github.com`, `api.github.com`, `ghcr.io` and its blob host) and, for `sast.yml` with a
  registry pack such as the default `p/default`, to `semgrep.dev`, which serves the rules at run
  time. They write their GHCR login under `RUNNER_TEMP`, which the runner empties at the start and
  end of each job, not to `~/.docker`.
- **No reach into anything that matters**: put it on a network segment that cannot reach your
  hosts, NAS or management interfaces.
- **Docker** is required (every job except `security-audit` runs its scanner as a container), and
  the user running the jobs needs access to the Docker socket. On a persistent host that socket is
  root-equivalent, which is one more reason to keep the runner disposable.
- **Private repos only.** GitHub's own guidance is not to attach self-hosted runners to public
  repositories, because any fork PR can run on them.
- **`security-audit` with `admin-token`**: the token sits in that job's environment, so the runner
  must not be shared with anything less trusted than the repo itself.

Each job's `timeout-minutes` is calibrated on hosted runners, where the toolbox images pull in
seconds. A self-hosted runner pulling them cold over a slow link can exceed it on the first run;
pre-pull the digests from the workflow files, or keep a warm image cache on the runner image.

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
| **First-party** (only where the field has a gap) | the enforcing gate for the developer-execution and config-injection surface (this repo); the assess-to-enforce compiler and engine-neutral policy contract (security-agents) | Build only where the field's coverage stops, and retire it when the field catches up. Four of the gate's five carriers are now blocked upstream too; `gate-proof.sh` hard-asserts the one that is not, so the day it closes, this row has to shrink. |
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
  # Every PR, plus a weekly scan of the default branch. If a ruleset requires PRs
  # with these checks, a push to main is a squash merge of a tree that was just
  # scanned on its PR, so a push trigger repeats the same work. The schedule
  # covers main independently (and the audit job runs only there).
  pull_request:
  schedule:
    - cron: '0 8 * * 1'
  workflow_dispatch:
  # Opt in only if the repo allows direct pushes to main, which no PR scan sees:
  # push:
  #   branches: [main]
  # Feature-branch pushes are already covered by their PR, so don't broaden this
  # to branches: ["**"] on a private repo; it double-bills Actions minutes.

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
| `security-scan.yml` | push / PR | Secret scanning (betterleaks from the pinned image), unpinned-action detection, SECURITY.md presence | `fail-on-findings` input; `secret-scan: false` skips betterleaks only. The potential-secret count goes to the job summary; details stay in the log, redacted |
| `security-audit.yml` | schedule | Repo settings: Dependabot alerts and auto-fix, Actions default permissions, delete-branch-on-merge, branch protection (rulesets or classic), SECURITY.md, declared vs actual visibility | Weekly is a sensible default. The four admin-only checks need repository `Administration: read`, which `GITHUB_TOKEN` cannot carry; without the optional `admin-token` secret they report a notice, not a verdict |
| `gha-security.yml` | `workflow_call` | Audits the caller's Actions workflows with `gha-toolbox`: zizmor (expression and template injection, excessive permissions, unpinned actions) plus actionlint (syntax and embedded shell via shellcheck) | Per-tool issue counts in the job summary and the annotation |
| `skill-audit.yml` | `workflow_call` | SkillSpector for the agent-execution surface, plus the first-party `skill-testfile-gate` for the developer-execution and config-injection surfaces. Two layers: presence (inventory) and malice (a Semgrep rule pack that blocks and emits SARIF) | **Blocks.** Needs `security-events: write` and `packages: read`. Gate SARIF retained as the `skill-audit-sarif` artifact where it is not uploaded; gate finding count in the job summary. See the [walkthrough](docs/gecko-vector-walkthrough.md) |
| `sast.yml` | `workflow_call` | Semgrep OSS from `sast-toolbox`; SARIF to code scanning, or retained as the `sast-sarif` run artifact where that upload is off or unavailable. Portable across public and private repos | Finding count, severity tally and located table in the job summary either way |
| `codeql.yml` | `workflow_call` | Deep whole-program SAST. Most public repos are better served by GitHub's default setup; use this for a centralized or advanced setup | |
| `iac-security.yml` | `workflow_call` | Checkov from `iac-toolbox`: Terraform, Dockerfiles, Kubernetes, Helm, CloudFormation; SARIF to code scanning, or retained as the `iac-sarif` run artifact where that upload is off (or fails on a private repo) | `framework` and `skip-frameworks` inputs. Finding count, severity tally and located table in the job summary either way. Fails if Checkov exits without writing SARIF |
| `ai-review.yml` | `workflow_call` | Wraps the official [anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review): Claude reviews the PR diff for injection, authorization, crypto, RCE, and business-logic flaws, with a second LLM pass to filter false positives | Opt-in. Needs `claude-api-key`. `findings-count` output, plus passthrough for model, excluded dirs, timeout, and custom instructions. Also available in Claude Code as `/security-review` |

`security-scan`, `gha-security`, `sast`, `iac-security` and `security-audit` all take a `runner`
input (default `ubuntu-latest`); see [self-hosted runners](#can-i-run-it-on-a-self-hosted-runner).

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
