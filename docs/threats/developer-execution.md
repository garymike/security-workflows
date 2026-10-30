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
SkillSpector does see a `.husky/` payload and does gate on exit code: it exits 1 above a
`risk_score` of 50 (`DO_NOT_INSTALL`), and it blocks the same payload class in a `.test.ts`
carrier at 64/100 and the git-hook carrier at 76/100. As of v2.13.0 it blocks both, so on this
profile's two original carriers the field has caught up; `gate-proof.sh` prints the live numbers
on every build. What it still clears is the persistent-memory-write carrier: 0/100 `SAFE`, "no
security issues detected", so a CI gate on exit codes lets that one through.
The research state of the art excludes the surface by scope.

## How this platform stops it
[`skill-testfile-gate`](../../toolbox/skill-audit/skill-testfile-gate.sh) inventories the auto-run
files and fails the build (exit 1) on malice, layered so honest tests do not trip it, emitting
SARIF. It covers every carrier in the list, including the ones scanner scoring lets pass.

## Proof
- Demos: [`gecko-demo`](../../tests/fixtures/gecko-demo), [`gecko-hook-demo`](../../tests/fixtures/gecko-hook-demo)
- Assertions: [`gate-proof.sh`](../../tests/gate-proof.sh) checks 1, 2, and the carrier-coverage gap (4)
- Decisions: [ADR-0010](../adr/0010-first-party-dev-exec-rule-pack.md), [ADR-0011](../adr/0011-developer-execution-surface-boundary.md)
- Deep dive: [the Gecko-vector walkthrough](../gecko-vector-walkthrough.md)

## Honest residual
Static rules are a pre-filter, not a trust gate; an adaptive author can obfuscate past them
([SkillCloak]). WARNING findings escalate to a sandboxed run (the Tier-2 skill-auditor). A git-stage
hook catches a skill that arrives through git, not one you download outside it.

On the agent-memory-write carrier specifically, the gate matches a destination it can read as a
literal. Two shapes measured as still passing, both one line to write:

- a destination assembled rather than written out, `open("MEM" + "ORY" + ".md", "a")`
- `open` reached through an indirection, so the call site has no filename in it

The line is the **basename**, not the path. A computed directory with a literal basename is
covered, including `open(f"{base}/MEMORY.md", "a")` and a raw Windows path, which are asserted as
checks 14 and 13. What still passes is an assembled or indirect basename, where no literal
filename appears at the call site at all.

Fixing those needs the path resolved rather than matched, which is a different kind of analysis
than this rule pack does. They are not asserted in [`gate-proof.sh`](../../tests/gate-proof.sh) on
purpose: an assertion that the gate does **not** catch something turns a weakness into expected
behaviour, and the next person to improve the rule would have to delete a passing test to do it.
Recorded here instead, where it reads as a limit rather than a feature.
