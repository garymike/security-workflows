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
| **Trivy** | Adopted | build pipeline | Gates publish on fixable CRITICAL image CVEs | Stays image-CVE-only; Checkov owns IaC |
| **Semgrep OSS** | Adopted | sast | Containerizable/pinnable, free public+private, portable; carries custom + LLM rules (closes Trusys); the shipped universal SAST | Interfile dataflow is paid — pair with CodeQL for depth |
| **CodeQL** | Adopted | `codeql.yml` | Deepest whole-program dataflow; shipped as a reusable workflow + recommended code-scanning default setup | Public-repo-free only, not containerizable — complementary, not the sole SAST |
| Trusys LLM Scan | Folded into Semgrep | sast | Semgrep-based; adopt the LLM ruleset, not the separate action | — |
| **Checkov** | Adopted | iac | pip-installable, broad IaC coverage (Terraform/Docker/K8s/Helm/CFN); dogfoodable on our Dockerfiles | — |
| KICS | Rejected | — | Redundant with Checkov (same surface); "dual-verify" is hoarding, not coverage | If Checkov misses a needed framework |
| Raven | Covered by zizmor | — | Same GHA expression-injection threat; zizmor is better-maintained | If Raven adds unique CI/CD graph coverage |
| poutine (BoostSecurity) | Rejected (for now) | — | Redundant with zizmor for GHA posture | If it covers something zizmor doesn't |
| Promptfoo | Future (agent tier) | — | Dynamic LLM-app red-teaming — needs app prompts/keys + a sandbox; belongs in a `security-agents` deployment, not a static scanner | When the dynamic tier is built |
| Cimon (eBPF) | Future (agent tier) | — | Dynamic runtime monitoring — crosses the static-only boundary | When the dynamic tier is built |
| mcp-stride-gpt / STRIDE skill | Out of scope here | — | Interactive LLM assistant, not a static scanner → `garymike/skills` | If an LLM-in-CI design-review gate is wanted ([ADR-0007](adr/0007-stride-in-ci-deferred.md)) |
| Cisco AI Agent Security Scanner | Watch | — | Open-sourced skill scanner; could complement/absorb the test-file gate | Evaluate for skill-audit-toolbox |
| **anthropics/claude-code-security-review** | Adopted (optional, AI layer) | `ai-review.yml` | Official Anthropic **AI-semantic PR diff review** (injection/authz/crypto/RCE + LLM false-positive filter) — fills the AI-review gap our *static* aggregation doesn't; MIT, maintained, SHA-pinned. Complements (does not overlap) the skill/MCP gates. Adopt-don't-rebuild: Anthropic manages the engine. | Opt-in: needs a Claude API key (per-run cost) + not prompt-injection-hardened (require external-contributor approval) |
