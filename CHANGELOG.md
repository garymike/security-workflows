# Changelog

All notable changes to this repo are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
