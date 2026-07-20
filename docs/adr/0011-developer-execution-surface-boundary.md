# 11. The developer-execution surface boundary

## Status
Accepted

## Context
"Which files does the gate treat as an execution surface?" needs a principled answer, or the gate
either misses vectors or over-scans into noise. The Gecko vector is broader than `*.test.ts`, and
skills can live in more places than a single top-level directory.

## Decision
Include a file iff it auto-executes without the developer explicitly choosing to run that
file:

- test files (runner auto-discovery: Jest / Vitest / Mocha / pytest, `__tests__/`, `conftest.py`),
- npm lifecycle scripts (`preinstall` / `postinstall` / `prepare` in `package.json`),
- Python packaging/interpreter hooks (`setup.py`, `*.pth`, `sitecustomize.py`, `usercustomize.py`),
- git hooks (`.git/hooks`, `.husky/`),
- test/build config auto-loaded by a runner (`*.config.{js,ts,mjs,cjs}`, `*.setup.*`, `.mocharc*`).

A `scripts/deploy.sh` the developer deliberately invokes does not qualify.

Scan every place skills can live (`code.claude.com/docs/en/skills#where-skills-live`): personal /
project / plugin / enterprise, nested `**/.claude/skills/` (monorepo), `.claude/commands/`, plus
`.cursor` / `.agents` (cross-agent, broader than Claude's own docs), following symlinks. Read
what other scanners are blind to: `.git/hooks` (*SkillCloak* Table I, 8 of 9 surveyed scanners skip
`.git/`). Exclude dependency trees (`node_modules`, `.venv`) and test-fixture dirs by default;
`GATE_NO_EXCLUDES=1` overrides (used by the CI proof-fixture to scan the intentional demo skills).

## Consequences
The boundary is itself a contribution: it turns "we flag test files" into "we defined the
developer-execution surface." Coverage remains a heuristic file list; new runner-discovered file
types are added as they appear (a documented residual in [threat-model.md](../threat-model.md)).
