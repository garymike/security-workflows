#!/usr/bin/env bash
# CI proof-fixture — the differentiator, checked on every dogfood build against the freshly built
# skill-audit-toolbox image. Hard-asserts the gate's own behavior; observes SkillSpector's.
#
#   1 (BLOCK)   skill-testfile-gate MUST block tests/fixtures/gecko-demo (developer-execution malice).
#   2 (CLEAR)   skill-testfile-gate MUST NOT block tests/fixtures/benign-skill (presence != malice —
#               the whole point of the presence->malice upgrade; a legit bundled test is not a finding).
#   3 (OBSERVE) SkillSpector's verdict on gecko-demo. If it passes clean, the developer-execution
#               surface is confirmed as its blind spot. Reported, not asserted (SkillSpector may still
#               pattern-match a bundled file; the differentiation is about the execution surface/scope).
#
# Usage: bash tests/gate-proof.sh [IMAGE]     (default: skill-audit-toolbox:ci)
set -uo pipefail
IMAGE="${1:-${GATE_IMAGE:-skill-audit-toolbox:ci}}"
FIX="$(cd "$(dirname "$0")/fixtures" && pwd)"
fail=0
gate() { docker run --rm -e GATE_NO_EXCLUDES=1 -v "$FIX/$1:/skill:ro" "$IMAGE" skill-testfile-gate /skill; }

echo "== 1. gate MUST block the malicious gecko-demo =="
if gate gecko-demo; then echo "  FAIL: gate did NOT block gecko-demo"; fail=1; else echo "  PASS: gate blocked gecko-demo (exit non-zero)"; fi

echo ""
echo "== 2. gate MUST NOT block the benign-skill =="
if gate benign-skill; then echo "  PASS: benign-skill not blocked (presence != malice)"; else echo "  FAIL: gate blocked a benign skill (false positive)"; fail=1; fi

echo ""
echo "== 3. observe: SkillSpector on gecko-demo (expected to pass — the surface it misses) =="
if docker run --rm -v "$FIX/gecko-demo:/skill:ro" "$IMAGE" skillspector scan /skill --no-llm >/dev/null 2>&1; then
  echo "  OBSERVED: SkillSpector PASSED gecko-demo -> developer-execution surface confirmed as its blind spot."
else
  echo "  OBSERVED: SkillSpector flagged gecko-demo (it also inspects the bundled file). The gate still"
  echo "            catches the developer-execution intent; the differentiation is on the execution surface."
fi

echo ""
if [ "$fail" -eq 0 ]; then echo "PROOF-FIXTURE PASSED — SkillSpector/gate differentiation holds."; else echo "PROOF-FIXTURE FAILED"; fi
exit "$fail"
