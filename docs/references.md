# References

The research and incident sources this project's threat model, ADRs, and rule pack are grounded in.
Kept here as a single canonical list so citations elsewhere can stay short and every claim is
traceable to a source you can re-check as the field moves (papers get revised, tools get patched).

Cite entries by their tag (e.g. **[SkillCloak]**) in prose; link back here for the full reference.

## Primary studies

- **[SkillScan]** Liu, Wang, Feng, Zhang, Xu, Deng, Li, Zhang, *Agent Skills in the Wild: An Empirical
  Study of Security Vulnerabilities at Scale.* arXiv 2601.10338 (2026). <https://arxiv.org/abs/2601.10338>.
  31,132 skills analysed; 26.1% carry ≥1 vulnerability; a 14-pattern / 4-category agent-execution
  taxonomy. Cited here for the scanner-scope boundary ("`SKILL.md` + scripts the skill may invoke")
  that excludes the developer-execution surface by construction, and the prevalence numbers.

- **[SkillCloak] / [SkillDetonate]** Ji, Xu, Li, Gao, Wei, Wang, Cheung (HKUST), *Cloak and Detonate:
  Scanner Evasion and Dynamic Detection of Agent Skill Malware.* arXiv 2607.02357 (2026).
  <https://arxiv.org/abs/2607.02357>. SkillCloak (payload-preserving evasion) bypasses >90% of nine
  scanners; SkillDetonate (sandboxed, eBPF+FUSE taint) catches 97%. Cited here for static analysis
  being a cheap pre-filter rather than a trust gate (which points to the escalate-to-sandbox ladder); the blind-dir table
  (8/9 scanners skip `.git/`); and that the dynamic SOTA detonates the agent, not the developer toolchain.

- **[MalSkillBench]** Guo, Zeng, Liu, Jia, Xu, Tang, Fang, Liu, *MalSkillBench: A Runtime-Verified
  Benchmark of Malicious Agent Skills.* arXiv 2606.07131 (2026). <https://arxiv.org/abs/2606.07131>.
  3,944 malicious / 4,000 benign, 108-cell taxonomy. Cited here for the "hybrid artifact" result
  (naive OR-combining detectors over-triggers, up to 3,979 FPs on 4,000 benign, so use layered severity).
  Practical access routes through the commercial Kirin platform (<https://www.getkirin.com>);
  treated as a reference, not a dependency.

## Incidents & vendor research

- **[Gecko]** Gecko Security / VentureBeat, *Anthropic Skill scanners passed every check. The malicious
  code rode in on a test file.* <https://venturebeat.com/security/anthropic-skill-scanners-passed-every-check-malicious-code-test-file>
  · research: <https://www.gecko.security/research>. The founding demonstration of the developer-execution
  (bundled test-file) vector this project's gate covers.

- **[ToxicSkills]** Snyk Security Labs, *ToxicSkills: malicious AI agent skills on ClawHub.*
  <https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/>. 76 payloads; curl|bash, base64-eval,
  memory-file poisoning (`MEMORY.md`/`SOUL.md`), password-ZIP evasion. Informs several malice rules.

- **[Datadog]** Datadog Security Labs, *Malicious coding agent skills and the risk of dynamic context.*
  <https://securitylabs.datadoghq.com/articles/malicious-skills-supply-chain-risks-in-coding-agents-with-dynamic-context/>.
  A cloned repo introduces skills without explicit install (motivates git-stage hooks); eBPF runtime monitoring.

- **[ConfigInjection]** Check Point Research (A. Donenfeld, O. Vanunu), *Critical Claude Code flaws:
  configuration injection via Hooks & MCP.*
  <https://blog.checkpoint.com/research/check-point-researchers-expose-critical-claude-code-flaws/> · coverage:
  <https://thehackernews.com/2026/02/claude-code-flaws-allow-remote-code.html> · secondary:
  <https://devops.com/security-flaws-in-anthropics-claude-code-risk-stolen-data-system-takeover/>.
  CVE-2025-59536 (CVSS 8.7): a repo's own `.claude` config (Hooks and MCP integrations)
  auto-executes shell commands on clone/open of an untrusted project, overriding the approval prompts (RCE, no
  consent). CVE-2026-21852 (5.3): repo-controlled config leading to API-key/token exfiltration. Cited here for the
  developer-execution surface extending to agent config-injection. Check Point's framing, "the risk now
  extends to opening untrusted projects," is a CVE-backed validation and expansion of exactly the surface the gate
  covers. Patched upstream (Anthropic, late-2025/early-2026); the gate is defense-in-depth for the class, a
  pre-open scan of auto-executing repo config.

- **[ClawHavoc]** Koi Security, *ClawHavoc: 341 malicious skills.*
  <https://www.koi.ai/blog/clawhavoc-341-malicious-clawedbot-skills-found-by-the-bot-they-were-targeting>.
  Dependency-impersonation campaign exfiltrating browser creds, keychain, SSH keys, crypto wallets.

- **Cato CTRL**, the "GIF Creator" skill that delivered MedusaLocker ransomware (Dec 2025); the "consent gap".

## Tools & standards

- **[SkillSpector]** NVIDIA, the skill scanner this project pairs the gate with. Advisory: it scans the bundled
  surface (incl. `.husky/` in v2.3+) and reports findings, but has no fail-on mode and exits 0; the gate
  enforces (exit 1) where it advises. <https://github.com/NVIDIA/SkillSpector>
- **[ClaudeReview]** Anthropic, *claude-code-security-review*: official AI-powered PR security review (Claude reads
  the diff for injection/authz/crypto/RCE/business-logic flaws; a second LLM pass filters false positives).
  <https://github.com/anthropics/claude-code-security-review> ·
  <https://www.anthropic.com/news/automate-security-reviews-with-claude-code>. Adopted as the optional
  AI-semantic review layer (`ai-review.yml`), complementary to the static aggregation and the skill/MCP gates
  (it reviews code diffs, not the developer-execution / MCP surfaces). Caveats: needs a Claude API key (cost);
  per Anthropic it is not hardened against prompt injection.
- **Semgrep** (OSS), the engine the developer-execution rule pack reuses. <https://semgrep.dev>
- **OWASP**, Agentic Skills Top 10 / MCP Top 10 / MCP Security Cheat Sheet. <https://genai.owasp.org> ·
  <https://owasp.org/www-project-mcp-top-10>
