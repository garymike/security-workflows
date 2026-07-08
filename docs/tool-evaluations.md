# Tool evaluations

A living ledger of security tools **assessed** for this aggregator — adopted, deferred,
or rejected — with rationale and a revisit trigger. It complements
`scripts/check-tool-updates.sh`: the script tracks *version* drift of tools we ship; this
ledger tracks *selection* decisions, so a tool that improves gets reconsidered rather than
forgotten.

| Tool | Status | Image / use | Rationale | Revisit trigger |
|---|---|---|---|---|
| **betterleaks** | Adopted | base | Best-in-class secrets, MIT, checksum-verified, agent-friendly CLI; drop-in gitleaks successor | — |
| gitleaks | Replaced | — | Superseded by betterleaks (same author) | — |
| **trufflehog** | Adopted | base | Complementary *verified*-secret depth (live provider validation) | If betterleaks' CEL validation fully subsumes it |
| **osv-scanner** / **syft** | Adopted | base | Dependency CVEs / SBOM — still best-fit | — |
| **pip-audit** / **snyk-agent-scan** | Adopted | mcp-review | Python dep audit / MCP tool-surface (ToxicSkills-validated) | — |
| **SkillSpector** | Adopted | skill-audit | NVIDIA; agent-execution surface (prompt injection, tool poisoning, exfil); SARIF; pinned by commit | On a tagged/PyPI release, pin to that instead of a commit |
| **skill-testfile-gate** | Adopted (first-party) | skill-audit | Covers the developer-execution surface no scanner covers (Gecko test-file vector) | **Sunset** when SkillSpector/Cisco add test-file inspection — upstream it |
| **zizmor** | Adopted | gha | Best-in-class GHA static analysis (expression injection, perms, unpinned actions) | — |
| **actionlint** | Adopted | gha | Workflow syntax + shellcheck; complementary to zizmor | — |
| **Trivy** | Adopted | build pipeline | Gates publish on fixable CRITICAL image CVEs | Could grow into a dedicated IaC role |
| **CodeQL** | Adopted (platform-native) | — | Free for public repos, best GitHub UI integration; the SAST answer | — |
| poutine (BoostSecurity) | Rejected (for now) | — | Redundant with zizmor for GHA posture | If it covers something zizmor doesn't |
| Semgrep OSS | Deferred | — | CodeQL covers the GitHub case | When an off-GitHub consumer needs portable SAST |
| Checkov / Trivy-IaC / KICS | Deferred | — | Low dogfood demand (Dockerfiles yes, Terraform/K8s no) | When a consumer repo actually has IaC |
| mcp-stride-gpt / STRIDE skill | Out of scope here | — | Interactive LLM assistant, not a static scanner → `garymike/skills` | If an LLM-in-CI design-review gate is wanted ([ADR-0007](adr/0007-stride-in-ci-deferred.md)) |
| Cisco AI Agent Security Scanner | Watch | — | Open-sourced skill scanner; could complement/absorb the test-file gate | Evaluate for skill-audit-toolbox |
