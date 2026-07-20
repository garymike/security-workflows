# Threat profiles

The proving ground. Each profile is one real attack: what it is, why existing tooling misses it or
only advises, a defanged runnable demo, how this platform enforces against it, and the CI proof that
re-checks it on every build. New threats become new profiles; the platform thesis does not move.

| Threat | Grounding | Status | Enforced by |
|---|---|---|---|
| [Developer-execution surface](developer-execution.md) | Gecko Security (2026); arXiv 2601.10338, 2607.02357 | Covered, enforced | `skill-testfile-gate` |
| [Config-injection](config-injection.md) | CVE-2025-59536 (Check Point) | Covered, enforced | `skill-testfile-gate` |
| [Memory-file poisoning](memory-poisoning.md) | Snyk ToxicSkills | Covered, enforced | `skill-testfile-gate` |

Roadmap (the material exists, the profile is pending): scanner evasion and packing (SkillCloak,
arXiv 2607.02357), an acknowledged residual rather than something the static gate blocks outright
(WARNING findings escalate to a sandboxed run instead). Full citations live in
[`../references.md`](../references.md); the runtime-side profiles (MCP tool poisoning, egress
exfiltration) live in the [security-agents](https://github.com/garymike/security-agents) catalog.
