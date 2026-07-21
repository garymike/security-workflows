# Tool evaluations

A living ledger of security tools assessed for this aggregator (adopted, deferred,
or rejected), with rationale and a revisit trigger. It complements
`scripts/check-tool-updates.sh`: the script tracks version drift of tools we ship; this
ledger tracks selection decisions, so a tool that improves gets reconsidered rather than
forgotten.

| Tool | Status | Image / use | Rationale | Revisit trigger |
|---|---|---|---|---|
| **betterleaks** | Adopted | base | Strong secrets coverage, MIT, checksum-verified, agent-friendly CLI; drop-in gitleaks successor | n/a |
| gitleaks | Replaced | n/a | Superseded by betterleaks (same author) | n/a |
| **trufflehog** | Adopted | base | Complementary verified-secret depth (live provider validation) | If betterleaks' CEL validation fully subsumes it |
| **osv-scanner** / **syft** | Adopted | base | Dependency CVEs / SBOM, still the best fit | n/a |
| **pip-audit** / **snyk-agent-scan** | Adopted | mcp-review | Python dep audit / MCP tool-surface (ToxicSkills-validated) | n/a |
| **SkillSpector** | Adopted | skill-audit | NVIDIA; agent-execution surface (prompt injection, tool poisoning, exfil); SARIF; pinned by commit | On a tagged/PyPI release, pin to that instead of a commit |
| **skill-testfile-gate** | Adopted (first-party) | skill-audit | Enforces on the developer-execution surface that scanners report but do not gate on (Gecko test-file vector) | Sunset when SkillSpector/Cisco add test-file gating; upstream it |
| **zizmor** | Adopted | gha | Strong GHA static analysis (expression injection, perms, unpinned actions) | n/a |
| **actionlint** | Adopted | gha | Workflow syntax + shellcheck; complementary to zizmor | n/a |
| **Trivy** | Adopted | build pipeline | Gates publish on fixable CRITICAL image CVEs | Stays image-CVE-only; Checkov owns IaC |
| **Semgrep OSS** | Adopted | sast | Containerizable/pinnable, free public+private, portable; carries custom + LLM rules (closes Trusys); the shipped universal SAST | Interfile dataflow is paid; pair with CodeQL for depth |
| **CodeQL** | Adopted | `codeql.yml` | Deepest whole-program dataflow; shipped as a reusable workflow + recommended code-scanning default setup | Public-repo-free only, not containerizable; complementary, not the sole SAST |
| Trusys LLM Scan | Folded into Semgrep | sast | Semgrep-based; adopt the LLM ruleset, not the separate action | n/a |
| **Checkov** | Adopted | iac | pip-installable, broad IaC coverage (Terraform/Docker/K8s/Helm/CFN); dogfoodable on our Dockerfiles | n/a |
| KICS | Rejected | n/a | Redundant with Checkov (same surface); "dual-verify" is hoarding, not coverage | If Checkov misses a needed framework |
| Raven | Covered by zizmor | n/a | Same GHA expression-injection threat; zizmor is better-maintained | If Raven adds unique CI/CD graph coverage |
| poutine (BoostSecurity) | Rejected (for now) | n/a | Redundant with zizmor for GHA posture | If it covers something zizmor doesn't |
| Promptfoo | Future (agent tier) | n/a | Dynamic LLM-app red-teaming, needs app prompts/keys plus a sandbox; belongs in a `security-agents` deployment, not a static scanner | When the dynamic tier is built |
| Cimon (eBPF) | Future (agent tier) | n/a | Dynamic runtime monitoring, crosses the static-only boundary | When the dynamic tier is built |
| mcp-stride-gpt / STRIDE skill | Out of scope here | n/a | Interactive LLM assistant, not a static scanner; lives in `garymike/skills` | If an LLM-in-CI design-review gate is wanted ([ADR-0007](adr/0007-stride-in-ci-deferred.md)) |
| Cisco AI Agent Security Scanner | Watch | n/a | Open-sourced skill scanner; could complement/absorb the test-file gate | Evaluate for skill-audit-toolbox |
| **anthropics/claude-code-security-review** | Adopted (optional, AI layer) | `ai-review.yml` | Official Anthropic AI-semantic PR diff review (injection/authz/crypto/RCE + LLM false-positive filter), fills the AI-review gap our static aggregation doesn't; MIT, maintained, SHA-pinned. Complements (does not overlap) the skill/MCP gates. Adopt-don't-rebuild: Anthropic manages the engine. | Opt-in: needs a Claude API key (per-run cost) + not prompt-injection-hardened (require external-contributor approval) |
