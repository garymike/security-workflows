#!/usr/bin/env bash
# CI proof-fixture — the differentiator, checked on every dogfood build against the freshly built
# skill-audit-toolbox image. Hard-asserts the gate's behavior; observes SkillSpector's.
#
#   1 (BLOCK)   gate MUST block gecko-demo — the test-file vector (malice in a *.test.ts).
#   2 (BLOCK)   gate MUST block gecko-hook-demo — the git-hook vector (malice in .husky/pre-commit).
#   3 (CLEAR)   gate MUST NOT block benign-skill (presence != malice — a legit bundled test is not a finding).
#   4 (DIFFER)  HARD: the gate blocks gecko-hook-demo while SkillSpector CLEARS it (SkillSpector does not
#               inspect .husky/). That is the crisp proof — a vector *neither* the static nor dynamic SOTA
#               (arXiv 2601.10338 / 2607.02357) covers. If a scanner ever starts inspecting .husky/, this
#               fails loudly so the demo can be revisited. SkillSpector's verdict on gecko-demo (the
#               test-file vector, which it scans as generic code) is only observed.
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
echo "== 4. differentiation (HARD): the gate blocks a vector SkillSpector clears =="
if ss gecko-hook-demo; then
  echo "  PASS: SkillSpector CLEARS gecko-hook-demo while the gate blocks it -> neither SOTA covers this surface."
else
  echo "  FAIL: SkillSpector flagged gecko-hook-demo, so the clean 'SkillSpector-passes / gate-blocks' claim no"
  echo "        longer holds (a scanner started inspecting .husky/). Revisit the demo."; fail=1
fi
# gecko-demo (test-file): SkillSpector scans .ts as generic code, so it flags this one — observed, not asserted.
if ss gecko-demo; then echo "  OBSERVED: SkillSpector cleared gecko-demo."; else echo "  OBSERVED: SkillSpector flagged gecko-demo (scans the bundled .test.ts as generic code)."; fi

echo ""
if [ "$fail" -eq 0 ]; then echo "PROOF-FIXTURE PASSED — the gate covers the developer-execution surface (both test-file and git-hook vectors)."; else echo "PROOF-FIXTURE FAILED"; fi
exit "$fail"
