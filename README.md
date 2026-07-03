# security-workflows

Reusable GitHub Actions security workflows for personal repos.

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

## Hardening note

The workflows in this repo use version tags (`@v4`, `@v2`) rather than SHA pins.
Pin them for maximum supply-chain safety once you've validated the setup.
