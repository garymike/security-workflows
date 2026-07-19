# Changelog

All notable changes to this repo are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.2] - 2026-07-13

### Docs
- **Captured CVE-2025-59536 (Check Point config-injection, CVSS 8.7) + CVE-2026-21852** in `docs/references.md`
  ([ConfigInjection]) and **scoped the agent config-injection surface** in `docs/threat-model.md` — a repo's own
  `.claude/settings.json` Hooks + `.mcp.json` MCP config auto-executing shell on *clone/open* is a CVE-backed
  instance of the developer-execution surface, applied to the agent's own config ("the risk now extends to opening
  untrusted projects"). Gate coverage of these config files is on the roadmap (not yet in the malice pack).

### Changed
- **`docs/threat-model.md`: corrected the SkillSpector overclaims fixed in 1.3.1** (this doc was missed then) —
  "the surface no published scanner covers" → "scanners advise; the gate enforces (exit 1)."

## [1.3.1] - 2026-07-11

### Changed
- **Corrected the skill-gate differentiator from "no scanner sees it" to "no scanner *gates* on it."**
  SkillSpector v2.3+ now scans bundled `.husky/` and `package.json` files and *reports* the developer-execution
  payload (a HIGH credential-access finding) — but it exits 0 (no fail-on mode), so a CI pipeline gating on exit
  codes still lets the skill through. `skill-testfile-gate` remains the purpose-built **enforcing** gate: it fails
  the build (exit 1) where advisory scanners do not, and the research state-of-the-art still excludes the surface
  by scope (arXiv 2601.10338 / 2607.02357). Re-framed the README, the Gecko walkthrough, the fixture comments, and
  the Dockerfile accordingly.
- **`tests/gate-proof.sh` #4 now asserts on behavior, not exit code.** The old assertion read SkillSpector's exit
  code (0) and mislabeled it "clears" — but SkillSpector reports findings and exits 0 regardless. #4 now proves the
  honest claim: the gate exits nonzero (enforces) while SkillSpector exits 0 (advises). A false-green proof made
  true.

---

## [1.3.0] - 2026-07-11

### Changed
- **`security-scan.yml` reusable: three parallel jobs collapsed into one.** The former
  `secrets` (betterleaks), `action-pinning`, and `security-md` jobs each billed a
  1-minute floor and re-ran `checkout` on every caller — ~3 billable minutes for seconds
  of work. They are now sequential steps in a single `scan` job (~1 billable minute), a
  ~66% cut per call for private-repo consumers. The advisory checks (action-pinning,
  SECURITY.md) run **before** the secret scan so they still emit even when a secret
  finding fails the job. No input/output changes; `packages: read` is still required (the
  betterleaks image is pulled from GHCR).
- **`self-scan.yml`: added `concurrency` with `cancel-in-progress`** so superseded dogfood
  runs cancel on rapid pushes.

### Docs
- **README usage example** now recommends `push: branches: [main]` + `pull_request`
  (instead of `branches: ["**"]`, which double-bills feature-branch pushes already covered
  by their PR), adds the `concurrency` block, and pins to `@v1.3.0`. A note explains public
  repos may broaden to `["**"]` since their Actions are free.

### Notes
- The check-run names visible to callers change from three named checks to a single
  "Security scan". This affects only consumers who pinned branch-protection required-status
  checks to the old names (none do here — see [ADR-0009](docs/adr/0009-solo-branch-protection.md)),
  so it is released as a minor, not a major.

## [1.2.0] - 2026-07-09

### Added
- **Local runner — the gate on any OCI runtime, no Docker Desktop required.** A new wrapper
  [`bin/skill-gate`](bin/skill-gate) auto-selects the first *functional* runtime
  (`docker` → `podman` → **WSL Containers `wslc`**), health-checking each (installed ≠ running), and
  translates Windows paths from git-bash automatically. It runs the **same signed
  `skill-audit-toolbox` image** as CI — one cryptographic source of truth, local and remote.
- **Second pre-commit hook `skill-testfile-gate-any`** (`language: script`, `entry: bin/skill-gate`)
  alongside the existing Docker-native `skill-testfile-gate` — same gate, runtime-agnostic, so the
  developer-execution vector can be caught locally on machines where Docker Desktop is blocked.
- **[docs/local-runner.md](docs/local-runner.md)** — the wrapper, the two hooks, a **manually
  verified** `wslc` command + environment, offline / air-gapped sideload (`wslc save`/`import`),
  the `virtiofs` ~2× file-perf note, enterprise GPO registry-allowlist alignment, and a deferred
  "beyond containers" QEMU note (Mac/Linux parity + VM-isolation for the Tier-2 dynamic sandbox).

### Notes
- WSLC is a **public preview** (GA planned fall 2026). The local `wslc` path is **verified manually**
  (Windows 11 build 26200.8737, WSL/wslc 2.9.3, no Docker) but **not exercised in CI** — the
  continuously-enforced guarantees remain the Docker path (`tests/gate-proof.sh`). `docker compose`
  is not yet supported by `wslc`, so the compose-based `security-agents` flavors stay on Docker; this
  track is the single-container **gate** only. No breaking changes; no new caller permissions.

---

## [1.1.0] - 2026-07-09

### Added
- **skill-testfile-gate v2 — the developer-execution surface, deepened.** The gate now separates
  **presence** (an auto-executed skill file exists — low-severity inventory) from **malice** (that
  file reads credentials, runs `curl|bash`, decode-and-execs, opens a reverse shell, writes agent
  memory, or is obfuscated — a blocking finding), via a first-party Semgrep rule pack
  (`toolbox/skill-audit/rules/agent-exec-surface.yml`). Legitimate bundled tests are no longer
  false-positived. See ADRs [0010](docs/adr/0010-first-party-dev-exec-rule-pack.md)–[0012](docs/adr/0012-layered-severity-and-sarif.md).
- **Wider scan scope** per the authoritative skill locations: recursive `**/.claude/skills/`
  (monorepo), plugin skills, `.claude/commands/`, `.cursor`/`.agents`, symlink-following, and git
  hooks (`.git/hooks`) — reading what other scanners are blind to.
- **SARIF output** from the malice layer, uploaded to code scanning (`skill-audit.yml` gains
  `upload-sarif`, default true, and `security-events: write`).
- **CI proof-fixture** (`tests/gate-proof.sh`, wired into `dogfood-scan`): asserts the gate blocks a
  defanged Gecko demo and clears a benign skill on every build — the differentiation, continuously proven.

### Changed
- `skill-audit-toolbox` now pins **Semgrep** explicitly (the gate's malice engine) instead of relying
  on SkillSpector's transitive pull.

### Migration
- **Callers of the reusable `skill-audit.yml` must now grant `security-events: write`** to the calling
  job (the gate uploads its malice-layer SARIF to code scanning, as `sast` / `iac-security` already do).
  Set `upload-sarif: false` to skip the upload, but the permission is still required by the workflow.

---

## [1.0.0] - 2026-07-08

First **stable** release — the reusable-workflow and image interfaces are declared stable;
consumers can pin to `@v1`. No functional change from `0.4.3`; this promotes the validated,
CI-hardened platform to 1.0.

Stable surface:
- **Reusable workflows** (`workflow_call`): `security-scan`, `security-audit`, `gha-security`, `skill-audit`, `sast`, `codeql`, `iac-security`.
- **Signed images**: `security-toolbox-base` → `mcp-review-toolbox`, `gha-toolbox`, `skill-audit-toolbox`, `sast-toolbox`, `iac-toolbox` (each SBOM'd, provenance-attested, Trivy-gated, cosign-signed).
- Validated end-to-end on a real multi-language repo; CI self-enforced (blocking actionlint / zizmor / Checkov / Trivy + self-scan invoking every reusable workflow).

---

## [0.4.3] - 2026-07-08

### Changed
- Hardened the dogfood CI: the `actionlint`, `zizmor`, and `Checkov` steps are now **blocking** (were informational — the gap that let the v0.4.0 invalid-permission bug ship), and the Trivy step is a blocking fixable-CRITICAL gate. Added `persist-credentials: false` to all checkouts.
- `self-scan.yml` now invokes **every reusable workflow** (security-scan, gha-security, sast, iac-security, skill-audit, security-audit) against this repo on every push/PR, so their parse/runtime errors are caught in CI — not only when a downstream repo calls them.

### Fixed
- `sast.yml`: quote-safe Semgrep config (a bash array instead of an unquoted string; shellcheck SC2086, surfaced by the now-blocking actionlint).
- `security-audit.yml`: admin-only setting reads (Actions default permissions, branch protection) now degrade gracefully under `contents: read` instead of failing the job under `bash -e` (surfaced by self-scan actually invoking the audit).

### Security
- Dropped over-broad `secrets: inherit` from `self-scan` (the reusable workflows only use the automatic `GITHUB_TOKEN`); added `persist-credentials: false` to all checkouts (zizmor `artipacked`); added a Dependabot `cooldown` so brand-new releases aren't adopted instantly (zizmor `dependabot-cooldown`).

---

## [0.4.2] - 2026-07-08

### Fixed
- `iac-security.yml`: Checkov's stdout is not clean SARIF (it prints a banner), so the uploaded SARIF was invalid JSON ("Unexpected token '_'"). Now writes SARIF via `--output-file-path` to a world-writable mounted dir. (Found by validating on a real consumer repo; Semgrep/CodeQL SARIF upload were already confirmed working there.)

---

## [0.4.1] - 2026-07-08

### Fixed
- `security-audit.yml`: removed an invalid `administration: read` entry from the workflow `permissions:` block — `administration` is not a valid `GITHUB_TOKEN` permission scope, so it made **every caller** of the reusable workflows fail at parse time ("workflow file issue"), even for the skipped audit job. Callers should pin to **v0.4.1**. (Caught by validating on a real consumer repo; making the dogfood actionlint step blocking is a follow-up to prevent recurrence.)

---

## [0.4.0] - 2026-07-08

### Added
- `CONTRIBUTING.md` — local image builds, the signed-commit/PR flow, and the release process.
- `sast-toolbox` (base + **Semgrep OSS**) + reusable `sast.yml` (SARIF → code scanning) and reusable `codeql.yml` (CodeQL, the deep engine for public repos) — defense-in-depth SAST that closes issue #2's SAST and #3's Trusys (Semgrep carries the LLM rulesets). CodeQL is also recommended via GitHub's code-scanning default setup.
- `iac-toolbox` (base + **Checkov**) + reusable `iac-security.yml` — Infrastructure-as-Code / misconfiguration scanning (Terraform, Dockerfiles, K8s, Helm, CloudFormation), SARIF → code scanning. Closes issue #2's IaC. (KICS rejected as redundant — see `docs/tool-evaluations.md`.)

### Fixed
- Documentation currency pass: `toolbox/README.md` and the root README now describe the full layered image set (not just `mcp-review-toolbox`), the Trivy publish gate, and the published release; `.github/repo-metadata.yml` purpose updated to the platform scope.
- Dogfood-driven hardening from the new `iac-toolbox` (Checkov): added top-level `permissions: contents: read` to the reusable workflows (CKV2_GHA_1); documented `.checkov.yaml` baseline for two non-applicable Dockerfile checks (HEALTHCHECK on CLI images; `${BASE}` is digest-pinned in CI).

---

## [0.3.0] - 2026-07-08

### Added
- `.github/dependabot.yml` — weekly update checks for GitHub Actions and the toolbox base image.
- `security-toolbox-base` — a separately-published, cosign-signed base image bundling the generic static scanners (gitleaks, trufflehog, osv-scanner, syft); the shared spine for every domain toolbox image (`toolbox/base/Dockerfile`).
- `self-scan.yml` — dogfoods the reusable `security-scan.yml` against this repo on every push/PR, so changes to the reusable workflow are validated here.
- `gha-toolbox` image (base + **zizmor** + **actionlint** + shellcheck) and the reusable **`gha-security.yml`** workflow — audits GitHub Actions workflows for expression/template injection, excessive permissions, unpinned actions, and shell issues. Built via the domain matrix and dogfooded in `dogfood-scan.yml`.
- `skill-audit-toolbox` image (base + **SkillSpector**, pinned by commit + a first-party **test-file gate**) and the reusable **`skill-audit.yml`** workflow — reviews agent skills across the agent-execution surface (SkillSpector) and the developer-execution / test-file surface no scanner covers. Adds **`docs/threat-model.md`** documenting the coverage map, citations, and residual gaps.
- **Trivy** image-CVE publish gate in `build-toolbox.yml` — each image is built locally and scanned for fixable CRITICAL CVEs *before* it is pushed and signed; publishing is blocked on findings. An informational Trivy scan is also added to `dogfood-scan.yml`.
- Documentation: `docs/adr/` (architecture decision records 0001–0009), `docs/architecture.md` (three-plane overview + layer graph), and `docs/tool-evaluations.md` (the tool-selection ledger).

### Fixed
- README "Hardening note" corrected: third-party actions are already pinned to commit SHAs (it previously described version tags).
- CHANGELOG 0.1.1 entry corrected: dropped a reference to `github/codeql-action`, which the repo does not use.
- Dogfood-driven workflow hardening (findings from the new gha-toolbox): quoted shell variables in `security-audit.yml` (shellcheck SC2086), moved `github.actor` into `env` in `security-scan.yml` (zizmor template-injection), and added `persist-credentials: false` to checkouts.

### Changed
- README lede repositioned from "workflows for personal repos" to the aggregator/platform framing.
- Toolbox restructured into layered images: `mcp-review-toolbox` (`toolbox/mcp-review/Dockerfile`) now builds `FROM security-toolbox-base` pinned by digest, adding only `pip-audit` + `snyk-agent-scan`. `build-toolbox.yml` builds/signs the base then the domain image(s) via matrix; `dogfood-scan.yml` builds the layered stack from source.
- Secret scanning swapped from **gitleaks** to **betterleaks** (its drop-in successor by the original author) across the base image, dogfood scan, composite action, and `tools.lock` / `check-tool-updates.sh`; `gitleaks` stays an accepted alias in the composite action.
- `security-scan.yml` (reusable) now runs secret scanning with **betterleaks from the pinned `security-toolbox-base` image** instead of `gitleaks-action` — one pinned source of truth. Input renamed `gitleaks-fail-on-findings` → `fail-on-findings`; the secrets job now needs `packages: read` to pull the image.
- Composite action `actions/mcp-review-toolbox` → **`actions/toolbox-scan`** (generalized; default image is now `security-toolbox-base`).
- Adopted SemVer release tagging (this is `0.3.0`). README usage now pins to a release tag and grants `packages: read`; SHA-pinning documented for maximum supply-chain safety.

---

## [0.2.0] - 2026-07-03

### Added
- `toolbox/` — `mcp-review-toolbox`, a pinned container image bundling static security scanners (gitleaks, trufflehog, osv-scanner, syft, pip-audit, snyk-agent-scan) for reviewing MCP servers and any repo. Base image digest-pinned; Go tools verified against release-published checksums; Python tools exact-pinned to PyPI wheels.
- `actions/mcp-review-toolbox/` — composite action wrapping the image for CI use.
- `.github/workflows/build-toolbox.yml` — build, SBOM, provenance, cosign keyless signing, and GHCR push (weekly + on change); reports pinned-tool version drift.
- `.github/workflows/dogfood-scan.yml` — builds the toolbox from source and scans this repo on push/PR.
- `scripts/check-tool-updates.sh` — compares pinned tool versions against upstream latest.

---

## [0.1.1] - 2026-07-03

### Fixed
- `security-scan.yml`: grant `pull-requests: read` permission so `gitleaks-action` can list PR commits on pull_request events.

### Changed
- Pinned all third-party actions to commit SHAs for supply-chain safety (`actions/checkout`, `gitleaks/gitleaks-action`).

### Added
- `SECURITY.md` — private vulnerability reporting instructions.
- `.github/repo-metadata.yml` — visibility intent declaration.

---

## [0.1.0] - 2026-07-03

### Added
- `security-scan.yml` — reusable workflow (push + PR): gitleaks secret scanning, unpinned action version detection, SECURITY.md presence check.
- `security-audit.yml` — reusable workflow (schedule + dispatch): Dependabot alerts and auto-fix, Actions default permissions, delete-branch-on-merge, branch protection, visibility intent check against `.github/repo-metadata.yml`.
- `README.md` — documents both workflows and the caller pattern.
