#!/usr/bin/env bash
# CI proof-fixture: the differentiator, checked on every dogfood build against the freshly built
# skill-audit-toolbox image. Hard-asserts the gate's behavior; observes SkillSpector's.
#
#   1 (BLOCK)   gate MUST block gecko-demo, the test-file vector (malice in a *.test.ts).
#   2 (BLOCK)   gate MUST block gecko-hook-demo, the git-hook vector (malice in .husky/pre-commit).
#   3 (CLEAR)   gate MUST NOT block benign-skill (presence != malice, a legit bundled test is not a finding).
#   4 (ENFORCE) HARD: the gate FAILS the build on gecko-hook-demo (exit!=0) while SkillSpector exits 0.
#               SkillSpector v2.3+ DOES report the payload (a HIGH credential-access finding), it is not
#               blind, but it has no fail-on mode, so it never gates: a CI pipeline that trusts exit codes
#               would let this skill through with SkillSpector alone. The gate is a purpose-built enforcing
#               gate for this surface. (The research SOTA still excludes the surface by scope: arXiv
#               2601.10338 scans SKILL.md + invoked scripts; 2607.02357 detonates the agent path, not
#               `npm test`.) If SkillSpector ever grows a fail-on/gating mode, #4 fails loudly to revisit this.
#   5 (BLOCK)   gate MUST block config-injection-demo, the agent's own auto-run config (CVE-2025-59536).
#   6 (CLEAR)   gate MUST NOT block config-injection-benign (npx MCP + an innocuous hook warn, do not fail).
#   7 (BLOCK)   gate MUST block memory-poisoning-demo, a write to persistent agent memory (Snyk ToxicSkills).
#
# Usage: bash tests/gate-proof.sh [IMAGE]     (default: skill-audit-toolbox:ci)
set -uo pipefail
IMAGE="${1:-${GATE_IMAGE:-skill-audit-toolbox:ci}}"
FIX="$(cd "$(dirname "$0")/fixtures" && pwd)"
fail=0
gate() { docker run --rm -e GATE_NO_EXCLUDES=1 -v "$FIX/$1:/skill:ro" "$IMAGE" skill-testfile-gate /skill; }
ss()   { docker run --rm -v "$FIX/$1:/skill:ro" "$IMAGE" skillspector scan /skill --no-llm >/dev/null 2>&1; }

echo "== 1. gate MUST block the test-file vector (gecko-demo) =="
if gate gecko-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked"; fi

echo ""
echo "== 2. gate MUST block the git-hook vector (gecko-hook-demo) =="
if gate gecko-hook-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked"; fi

echo ""
echo "== 3. gate MUST NOT block the benign skill =="
if gate benign-skill; then echo "  PASS: not blocked (presence != malice)"; else echo "  FAIL: false positive"; fail=1; fi

echo ""
echo "== 4. enforce vs advise (HARD): the gate FAILS the build where SkillSpector does not =="
# The gate must exit nonzero (enforce) on the git-hook vector.
if gate gecko-hook-demo >/dev/null 2>&1; then gate_enforces=0; else gate_enforces=1; fi
# SkillSpector must exit 0 (advise): it reports the payload but has no fail-on mode, so an exit-code CI gate
# would NOT stop this skill. That gap is exactly what the gate closes.
if ss gecko-hook-demo; then ss_gates=0; else ss_gates=1; fi
if [ "$gate_enforces" -eq 1 ] && [ "$ss_gates" -eq 0 ]; then
  echo "  PASS: the gate exits nonzero (fails CI/pre-commit) while SkillSpector exits 0 (advisory, no fail-on)."
  echo "        An exit-code CI gate would let this skill through with SkillSpector alone; the gate blocks it."
else
  echo "  FAIL: expected gate-enforces (exit!=0) + SkillSpector-advisory (exit 0); got gate=$gate_enforces ss=$ss_gates."
  echo "        If SkillSpector now gates (exit!=0), the enforce-vs-advise framing needs revisiting."; fail=1
fi

echo ""
echo "== 5. gate MUST block the config-injection vector (config-injection-demo) =="
if gate config-injection-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked (Hooks/env/MCP config auto-runs on repo open)"; fi

echo ""
echo "== 6. gate MUST NOT block benign config (config-injection-benign) =="
if gate config-injection-benign; then echo "  PASS: not blocked (npx MCP + innocuous hook warn, do not fail)"; else echo "  FAIL: false positive on standard config"; fail=1; fi

echo ""
echo "== 7. gate MUST block the memory-poisoning vector (memory-poisoning-demo) =="
if gate memory-poisoning-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked (write to MEMORY.md, cross-session instruction poisoning)"; fi

echo ""
if [ "$fail" -eq 0 ]; then echo "PROOF-FIXTURE PASSED: the gate covers the developer-execution surface (test-file, git-hook, config-injection, and memory-poisoning vectors)."; else echo "PROOF-FIXTURE FAILED"; fi
exit "$fail"
