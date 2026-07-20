# Architecture

`security-workflows` aggregates upstream security tooling, organized in three planes over a
pinned, signed supply chain.

## Three planes

1. **Reusable workflows** (`workflow_call`): the public interface other repos call:
   - `security-scan.yml`: secret scanning (betterleaks, via the pinned image), action-pinning, and SECURITY.md checks
   - `security-audit.yml`: repo posture (Dependabot, Actions permissions, branch protection, visibility intent)
   - `gha-security.yml`: GitHub Actions security (zizmor plus actionlint)
   - `skill-audit.yml`: agent-skill review (SkillSpector plus the developer-execution `skill-testfile-gate`)
2. **Domain toolbox images**: signed, use-case-scoped containers; the execution substrate.
3. **Supply-chain CI**: build, cosign-sign, SBOM, provenance, Trivy-gate, plus tool-drift detection.

## Image layer graph

```
security-toolbox-base    ← betterleaks · trufflehog · osv-scanner · syft (generic spine)
  ├── mcp-review-toolbox  ← + pip-audit · snyk-agent-scan
  ├── gha-toolbox         ← + zizmor · actionlint (+ shellcheck)
  └── skill-audit-toolbox ← + SkillSpector · skill-testfile-gate
```

Each domain image is digest-pinned to the base, SBOM'd, provenance-attested (`mode=max`),
Trivy-gated on fixable CRITICAL CVEs before publish, and cosign-signed (keyless, Sigstore/OIDC).
`dogfood-scan.yml` builds the whole stack from source and runs it against this repo on every
push and PR; `self-scan.yml` runs the reusable `security-scan` against this repo.

## Principles

- **Aggregator, not a fork:** pinned upstream tools, never vendored source ([ADR-0004](adr/0004-aggregator-not-a-fork.md)).
- **Toolbox images are the single source of truth:** workflows orchestrate them ([ADR-0003](adr/0003-toolbox-single-source-of-truth.md)).
- **Signal, not a verdict:** honest about residual gaps ([ADR-0006](adr/0006-skill-scanning-is-signal-not-verdict.md), [threat model](threat-model.md)).
- **Static only:** dynamic analysis (running an untrusted target) stays in the caller's sandbox.

## Verifying a published image

```bash
cosign verify ghcr.io/garymike/security-workflows/security-toolbox-base:latest \
  --certificate-identity-regexp 'https://github.com/garymike/security-workflows/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

See [`adr/`](adr/) for the decision log and [`threat-model.md`](threat-model.md) for the
skill-audit coverage map.
