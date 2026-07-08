# 6. Skill scanning is a signal, not a verdict

## Status
Accepted

## Context
Published skill scanners (SkillSpector, Cisco, Snyk, VirusTotal) inspect the
agent-execution surface (`SKILL.md`, agent-invoked scripts). Research (Gecko, 2026)
showed malicious payloads riding in on bundled test files that execute via the
*developer's* test runner — outside every scanner. Static scanners are also evadable
(SkillCloak packing; scan-time / TOCTOU rewriting).

## Decision
Position skill scanning as **signal + defense-in-depth, never a safety verdict**. Ship
`skill-testfile-gate` to cover the developer-execution surface the vendors miss, and
document residual gaps honestly in [`docs/threat-model.md`](../threat-model.md) rather
than implying "safe".

## Consequences
The differentiator is *covering the documented blind spot*, not claiming completeness.
Mitigations that scanning cannot provide (commit-pinning, test-runner glob exclusion,
sandboxed dynamic analysis) are documented as required companions.
