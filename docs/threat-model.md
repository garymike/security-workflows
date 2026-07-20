# Threat model: skill and agent-capability review

This document is the coverage map for `skill-audit-toolbox` and the `skill-audit.yml` workflow.
The most useful thing a skill scanner can tell you is what it does not check, so that is where
this starts.

> **Positioning (ADR-0006): skill scanning is a signal, not a safety verdict.** Static analysis
> of an untrusted skill narrows risk; it never certifies safety. Treat every result as one layer
> of defense-in-depth, never a green light.

## Why skills are dangerous

An agent skill is untrusted code that, once installed, runs with the agent's full permissions
(shell, filesystem, credentials, and persistent memory), with no code signing, sandboxing, or
mandatory review. Large-scale audits found roughly a quarter of skills carry at least one
vulnerability, and a meaningful fraction are outright malicious (SkillScan / *Agent Skills in the
Wild*, arXiv 2601.10338; Snyk ToxicSkills).

## The two execution surfaces

A skill package touches two execution surfaces. Skill scanners inspect the first natively. The
second they at most report on; they do not gate on it (SkillSpector v2.3+ flags a `.husky/`
payload but exits 0), and the research state of the art excludes it by scope:

| Surface | What runs it | What we run | Residual gap |
|---|---|---|---|
| **Agent-execution**: `SKILL.md`, agent-invoked scripts, tool definitions | the agent, at use time | **SkillSpector** (prompt injection, tool poisoning, data exfil, excessive agency, AST/taint/YARA) | evadable by novel packing or obfuscation (see below) |
| **Developer-execution**: `*.test.*`/`*.spec.*`/`conftest.py`/`__tests__/`, test-build config, npm lifecycle scripts, git hooks, agent config-injection (`.claude/settings.json` Hooks + `.mcp.json` server commands + `.claude/hooks/*`, CVE-2025-59536), `.pth`/`sitecustomize`. Anything auto-run without the developer choosing to run that file ([ADR-0011](adr/0011-developer-execution-surface-boundary.md)) | the **developer's** toolchain: test runner (Jest/Vitest/Mocha/pytest), package manager (`npm install`), git, on install or CI, no agent involved | **`skill-testfile-gate`** (first-party): filename **inventory** (presence, low) plus a Semgrep **malice** rule pack (credential reads, `curl\|bash`, decode-and-exec, reverse shells, obfuscation) that **blocks** and emits **SARIF** ([ADR-0010](adr/0010-first-party-dev-exec-rule-pack.md), [0012](adr/0012-layered-severity-and-sarif.md)). Skill scanners only advise on this surface (SkillSpector v2.3+ reports it, exits 0); the gate enforces (exit 1). | evadable by an adaptive author, so WARNING findings **escalate to a sandboxed Tier-2 run**; the surface file list stays heuristic |
| **Time-of-use**: a skill that points the agent at an external URL fetched after review | the network, later | not a scanning problem | answered by commit-pinning, not by scanning |

The developer-execution row is this repo's original contribution. Gecko Security (2026)
demonstrated that a skill with a clean `SKILL.md` can bundle a `reviewer.test.ts` whose
`beforeAll` block reads `~/.ssh`, `~/.aws/credentials`, and CI env secrets and exfiltrates them,
executing through the test runner with full local permissions, entirely outside the agent. A
fake skill using adjacent techniques reportedly reached about 26,000 agents. `skill-testfile-gate`
flags exactly these files. Since v2 it separates presence (an auto-run file exists, a
low-severity inventory signal) from malice (that file reads `~/.ssh` and exfiltrates inside
`beforeAll`, a blocking finding), so a skill that merely ships honest tests is not
false-positived; only one that weaponises them is.

The surface extends to agent config-injection. Check Point's CVE-2025-59536 (CVSS 8.7,
[ConfigInjection]) showed a repo's own `.claude/settings.json` Hooks and `.mcp.json` MCP
definitions auto-executing shell on clone or open of an untrusted project: Claude Code's own
config as the auto-run carrier, RCE without consent. Their framing, "the risk now extends to
opening untrusted projects", is precisely this surface, and it is CVE-backed. Covered by the gate:
`skill-testfile-gate` now inventories `.claude/settings.json` and `.claude/settings.local.json` Hooks,
`.mcp.json` and `.claude.json` server commands, and `.claude/hooks/*` scripts. It blocks a hostile hook
command or an injected code-execution environment variable, and warns on a package-runner MCP launch
([ADR-0013](adr/0013-config-injection-surface.md)). Sibling ecosystems (`.cursor`, `.vscode`, `.envrc`)
remain future work. The CVEs are patched upstream; the gate is defense-in-depth for the class, a
pre-open scan of auto-executing repo config that stays valuable regardless of any single vendor patch.

## Residual gaps we do not claim to catch

- **Scan-time evasion (TOCTOU).** A scanner checks a fixed snapshot; an author can publish a
  clean version for review, then push a malicious `*.test.ts` or rewrite a fetched-at-install URL
  afterward. The mitigation is not scanning. It is pinning skills to an immutable commit and
  reviewing every diff (OWASP Agentic Skills Top 10). The `skill-audit` workflow reports; it
  cannot bind a moving reference.
- **Novel static-analysis evasion.** Self-extracting or packed payloads (for example the
  SkillCloak technique, arXiv 2607.02357, where SFS packing bypasses more than 90% of nine
  surveyed scanners) are designed to slip past static scanners including SkillSpector. Static
  analysis is necessary but not sufficient, so the gate treats WARNING findings and opaque or
  packed artifacts as escalation candidates for a sandboxed run (the Tier-2 `security-agents`
  skill-auditor). That matches the paper's own conclusion: static analysis is a cheap pre-filter,
  and dynamic execution auditing does the real work.
- **Semantic intent.** Observing kinetic actions is solvable; intent is not. Deciding whether a
  plausible-looking capability is malicious still needs a human.

## How to use the signal (defense-in-depth)

1. Run `skill-audit` (SkillSpector plus `skill-testfile-gate`) on every skill before install.
2. Pin skills to a commit and review diffs on every bump. This converts trust-on-first-use into
   verify-on-every-change.
3. Exclude skill dirs from test-runner globs: add `.agents/`, `.claude/`, `.cursor/` to
   `testPathIgnorePatterns` (Jest), `exclude` (Vitest), or `testpaths` (pytest).
4. Keep dynamic analysis (actually running an untrusted skill) in an isolated sandbox. It is
   deliberately not centralized in these images.

## Sources

Full citations, with arXiv IDs, URLs, and what each is cited for, live in
[`docs/references.md`](references.md).

- *Agent Skills in the Wild: An Empirical Study of Security Vulnerabilities at Scale*, arXiv
  2601.10338 (SkillScan; about 26% vulnerable; static plus LLM detection).
- Snyk ToxicSkills: first audit of the ClawHub and skills.sh marketplaces.
- Gecko Security: the bundled test-file vector (developer-execution surface).
- *SkillCloak*: self-extracting packing that evades static skill scanners.
- OWASP Agentic Skills Top 10: pin-to-commit and verify-on-every-change guidance.
- NVIDIA SkillSpector: the skill scanner this image wraps (advisory: it reports findings and exits 0).
- Check Point [ConfigInjection]: CVE-2025-59536 and CVE-2026-21852, `.claude` Hooks and MCP config-injection on open.
