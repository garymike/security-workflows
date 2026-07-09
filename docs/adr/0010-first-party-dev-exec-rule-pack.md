# 10. A first-party rule pack for the developer-execution surface

## Status
Accepted

## Context
`skill-testfile-gate` originally flagged the *presence* of auto-executed skill files
(test/config/hook) by filename. Presence is not malice — legitimate skills ship tests — so a
filename-only gate cries wolf on every honest test suite. Distinguishing a benign test from a
weaponized one needs content analysis. [ADR-0004](0004-aggregator-not-a-fork.md) says we aggregate
best-in-class tools rather than build and maintain detection logic — but no published tool covers
this surface (that is the whole differentiator), and the state-of-the-art study
(arXiv 2601.10338, *SkillScan*) scopes itself to "`SKILL.md` + scripts the skill *may invoke*" — the
agent-execution path — excluding the developer-execution surface **by construction**.

## Decision
Author a small first-party Semgrep rule pack (`toolbox/skill-audit/rules/agent-exec-surface.yml`)
for the developer-execution surface. This is the one place building detection is justified, because
there is nothing to aggregate. It **reuses the Semgrep engine we already ship** (sast-toolbox), so it
honours ADR-0004's spirit — reuse the engine, author rules, do not build a parser. Semgrep is pinned
explicitly in `skill-audit-toolbox` (not left to SkillSpector's transitive pull).

## Consequences
We own ~9 rules — deliberately **table-stakes primitives** (credential reads, `curl|bash`,
decode-and-exec, reverse shells, agent-memory writes, obfuscation tells), the same class SkillScan's
own regexes use. An adaptive author can obfuscate past any static rule (*SkillCloak*, arXiv 2607.02357:
SFS Packing bypasses >90% of nine scanners), so the pack is a **cheap pre-filter, not a trust gate**
(see [ADR-0006](0006-skill-scanning-is-signal-not-verdict.md)); WARNING findings are flagged to
escalate to a sandboxed (Tier-2) run. If an upstream tool ever covers this surface, we retire the pack
and aggregate instead.
