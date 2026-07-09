# Threat model — skill & agent-capability review

This document is the honest coverage map for `skill-audit-toolbox` and the
`skill-audit.yml` workflow. It exists because the most important thing a skill
scanner can tell you is **what it does *not* check**.

> **Positioning (ADR-0006): skill scanning is a *signal*, not a safety verdict.**
> Static analysis of an untrusted skill narrows risk; it never certifies safety.
> Treat every result as one layer of defense-in-depth, never a green light.

## Why skills are dangerous

An agent skill is untrusted code that, once installed, runs with the **agent's full
permissions** — shell, filesystem, credentials, and persistent memory — with no code
signing, sandboxing, or mandatory review. Large-scale audits found roughly **a quarter
of skills carry at least one vulnerability**, and a meaningful fraction are outright
malicious (SkillScan / *Agent Skills in the Wild*, arXiv 2601.10338; Snyk **ToxicSkills**).

## The two execution surfaces

The critical insight is that a skill package touches **two** execution surfaces, and
every published scanner inspects only the first:

| Surface | What runs it | What we run | Residual gap |
|---|---|---|---|
| **Agent-execution** — `SKILL.md`, agent-invoked scripts, tool definitions | the agent, at use time | **SkillSpector** (prompt injection, tool poisoning, data exfil, excessive agency, AST/taint/YARA) | evadable by novel packing / obfuscation (see below) |
| **Developer-execution** — `*.test.*`/`*.spec.*`/`conftest.py`/`__tests__/`, test-build config, **npm lifecycle scripts**, **git hooks**, `.pth`/`sitecustomize` — anything auto-run without the developer choosing to run *that file* ([ADR-0011](adr/0011-developer-execution-surface-boundary.md)) | the **developer's** toolchain — test runner (Jest/Vitest/Mocha/pytest), package manager (`npm install`), git — on install/CI, **no agent involved** | **`skill-testfile-gate`** (first-party): filename **inventory** (presence, low) + a Semgrep **malice** rule pack (credential reads, `curl\|bash`, decode-and-exec, reverse shells, obfuscation) that **blocks** and emits **SARIF** ([ADR-0010](adr/0010-first-party-dev-exec-rule-pack.md), [0012](adr/0012-layered-severity-and-sarif.md)). The surface *no* published scanner covers. | evadable by an adaptive author → WARNING findings **escalate to a sandboxed Tier-2 run**; surface file list stays heuristic |
| **Time-of-use** — a skill that points the agent at an external URL fetched *after* review | the network, later | *(not a scanning problem)* | **answered by commit-pinning**, not by scanning |

The developer-execution row is this repo's original contribution. Gecko Security (2026)
demonstrated that a skill with a clean `SKILL.md` can bundle a `reviewer.test.ts` whose
`beforeAll` block reads `~/.ssh`, `~/.aws/credentials`, and CI env secrets and exfiltrates
them — executing through the test runner with full local permissions, entirely outside
the agent. A fake skill using adjacent techniques reportedly reached ~26,000 agents while
passing every scanner. `skill-testfile-gate` flags exactly these files — and, since v2, it
separates **presence** (an auto-run file exists — a low-severity inventory signal) from
**malice** (that file reads `~/.ssh` and exfiltrates inside `beforeAll` — a blocking finding),
so a skill that merely ships honest tests is not false-positived; only one that weaponises them.

## Residual gaps we deliberately do NOT claim to catch

- **Scan-time evasion (TOCTOU).** A scanner checks a fixed snapshot; an author can publish
  a clean version for review, then push a malicious `*.test.ts` or rewrite a fetched-at-
  install URL afterward. **Mitigation is not scanning — it is pinning skills to an immutable
  commit and reviewing every diff** (OWASP Agentic Skills Top 10). The `skill-audit` workflow
  reports; it cannot bind a moving reference.
- **Novel static-analysis evasion.** Self-extracting/packed payloads (e.g. the *SkillCloak*
  technique, arXiv 2607.02357 — SFS Packing bypasses >90% of nine surveyed scanners) are
  designed to slip past static scanners including SkillSpector. Static analysis is necessary,
  not sufficient — so the gate treats WARNING findings and opaque/packed artifacts as
  **escalation candidates for a sandboxed run** (the Tier-2 `security-agents` skill-auditor),
  matching that paper's own conclusion: static = cheap pre-filter, dynamic execution auditing
  = the load-bearing defense.
- **Semantic intent.** "Observing kinetic actions is solvable; intent is not." Deciding
  whether a plausible-looking capability is *malicious* still needs a human.

## How to use the signal (defense-in-depth)

1. Run `skill-audit` (SkillSpector + `skill-testfile-gate`) on every skill before install.
2. **Pin skills to a commit**, review diffs on every bump — converts trust-on-first-use into
   verify-on-every-change.
3. **Exclude skill dirs from test-runner globs** — add `.agents/`, `.claude/`, `.cursor/` to
   `testPathIgnorePatterns` (Jest) / `exclude` (Vitest) / `testpaths` (pytest).
4. Keep dynamic analysis (actually running an untrusted skill) in an isolated sandbox — it is
   deliberately **not** centralized in these images.

## Sources

Full citations — arXiv IDs, URLs, and what each is cited for — live in [`docs/references.md`](references.md).

- *Agent Skills in the Wild: An Empirical Study of Security Vulnerabilities at Scale*,
  arXiv 2601.10338 (SkillScan; ~26% vulnerable; static + LLM detection).
- Snyk, **ToxicSkills** — first audit of the ClawHub / skills.sh marketplaces.
- Gecko Security — the bundled **test-file** vector (developer-execution surface).
- *SkillCloak* — self-extracting packing that evades static skill scanners.
- OWASP **Agentic Skills Top 10** — pin-to-commit / verify-on-every-change guidance.
- NVIDIA **SkillSpector** — the agent-execution-surface scanner this image wraps.
