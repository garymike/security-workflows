# Threat: the developer-execution surface

**Grounding:** Gecko Security / VentureBeat (2026); excluded by the research state of the art by
scope ([SkillScan] arXiv 2601.10338, [SkillCloak] / [SkillDetonate] arXiv 2607.02357). Full
citations in [`../references.md`](../references.md).
**Surface:** developer-execution (auto-run by the toolchain, outside the agent).
**Status:** Covered, enforced.

## The attack
A skill ships a clean `SKILL.md` alongside a bundled `*.test.ts` or `.husky/pre-commit`. When the
developer runs `npm test` or `git commit`, the test runner or git auto-executes it, with full local
permissions and the agent nowhere in the loop. The defanged demo reads `~/.ssh/id_rsa` and POSTs it
to `localhost`.

## Why tooling misses it
Skill scanners are scoped to the agent-execution surface (`SKILL.md` plus agent-invoked scripts).
SkillSpector v2.3+ does see a `.husky/` payload, but it has no fail-on mode and exits 0, so a CI
gate on exit codes lets it through. The research state of the art excludes the surface by scope.

## How this platform stops it
[`skill-testfile-gate`](../../toolbox/skill-audit/skill-testfile-gate.sh) inventories the auto-run
files and fails the build (exit 1) on malice, layered so honest tests do not trip it, emitting
SARIF. It enforces where scanners advise.

## Proof
- Demos: [`gecko-demo`](../../tests/fixtures/gecko-demo), [`gecko-hook-demo`](../../tests/fixtures/gecko-hook-demo)
- Assertions: [`gate-proof.sh`](../../tests/gate-proof.sh) checks 1, 2, and the enforce-vs-advise gap (4)
- Decisions: [ADR-0010](../adr/0010-first-party-dev-exec-rule-pack.md), [ADR-0011](../adr/0011-developer-execution-surface-boundary.md)
- Deep dive: [the Gecko-vector walkthrough](../gecko-vector-walkthrough.md)

## Honest residual
Static rules are a pre-filter, not a trust gate; an adaptive author can obfuscate past them
([SkillCloak]). WARNING findings escalate to a sandboxed run (the Tier-2 skill-auditor). A git-stage
hook catches a skill that arrives through git, not one you download outside it.
