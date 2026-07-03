# Changelog

All notable changes to this repo are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.1] - 2026-07-03

### Fixed
- `security-scan.yml`: grant `pull-requests: read` permission so `gitleaks-action` can list PR commits on pull_request events.

### Changed
- Pinned all third-party actions to commit SHAs for supply-chain safety (`actions/checkout`, `gitleaks/gitleaks-action`, `github/codeql-action`).

### Added
- `SECURITY.md` — private vulnerability reporting instructions.
- `.github/repo-metadata.yml` — visibility intent declaration.

---

## [0.1.0] - 2026-07-03

### Added
- `security-scan.yml` — reusable workflow (push + PR): gitleaks secret scanning, unpinned action version detection, SECURITY.md presence check.
- `security-audit.yml` — reusable workflow (schedule + dispatch): Dependabot alerts and auto-fix, Actions default permissions, delete-branch-on-merge, branch protection, visibility intent check against `.github/repo-metadata.yml`.
- `README.md` — documents both workflows and the caller pattern.
