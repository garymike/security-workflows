# Changelog

All notable changes to this repo are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `.github/dependabot.yml` — weekly update checks for GitHub Actions and the toolbox base image.

### Fixed
- README "Hardening note" corrected: third-party actions are already pinned to commit SHAs (it previously described version tags).
- CHANGELOG 0.1.1 entry corrected: dropped a reference to `github/codeql-action`, which the repo does not use.

### Changed
- README lede repositioned from "workflows for personal repos" to the aggregator/platform framing.

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
