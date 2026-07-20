# Threat: memory-file poisoning

**Grounding:** Snyk Security Labs, *ToxicSkills: malicious AI agent skills on ClawHub* (76 payloads
audited; memory-file poisoning was one of the recurring patterns). See
[`../references.md`](../references.md), tag [ToxicSkills].
**Surface:** developer-execution (an auto-run file writing to the agent's own persistent state).
**Status:** Covered, enforced.

## The attack
An auto-executed file (a test's `beforeAll`, a lifecycle script, a git hook) writes into the agent's
persistent cross-session memory: `MEMORY.md`, `SOUL.md`, `AGENTS.md`, or files under `.claude/` or
`.cursor/`. Unlike a one-time credential theft, this is durable: the injected text is there to be
read back into every future session, steering the agent's behavior long after the skill that planted
it is gone.

## Why tooling misses it
Agent-execution scanners read `SKILL.md` and the scripts the agent invokes. A write to `MEMORY.md`
from a bundled test file is neither: it is not agent-invoked, and it is not the skill's own
declared instructions. It is a side effect of running the developer's toolchain, the same blind spot
as every other developer-execution vector, just aimed at the agent's memory instead of the
developer's credentials.

## How this platform stops it
[`skill-testfile-gate`](../../toolbox/skill-audit/skill-testfile-gate.sh) blocks on any auto-run file
whose write call targets `MEMORY.md`, `SOUL.md`, `AGENTS.md`, `.claude/`, or `.cursor/`
(`dev-exec-writes-agent-memory`, an ERROR-severity rule). Presence of an ordinary write is not
flagged; only a write that targets one of these specific persistence points is.

## Proof
- Demo: [`memory-poisoning-demo`](../../tests/fixtures/memory-poisoning-demo), a skill whose
  `SKILL.md` is honest and whose bundled test appends an instruction-injection payload to
  `MEMORY.md` on `beforeAll` (defanged: an inert canary line, never a working instruction).
- Assertion: [`gate-proof.sh`](../../tests/gate-proof.sh) check 7.
- Rule: [`agent-exec-surface.yml`](../../toolbox/skill-audit/rules/agent-exec-surface.yml),
  `dev-exec-writes-agent-memory`.

## Honest residual
The rule matches on a write call near one of the named paths; a payload that writes through an
indirection the regex does not recognize (a wrapper function, a path built at runtime) can evade it,
the same static-is-a-pre-filter limitation as every rule in the pack. A write that lands outside the
four named targets (a skill inventing its own persistence file the agent happens to read) is not
covered.
