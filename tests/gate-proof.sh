#!/usr/bin/env bash
# CI proof-fixture: the differentiator, checked on every dogfood build against the freshly built
# skill-audit-toolbox image. Hard-asserts the gate's behavior; observes SkillSpector's.
#
#   1 (BLOCK)   gate MUST block gecko-demo, the test-file vector (malice in a *.test.ts).
#   2 (BLOCK)   gate MUST block gecko-hook-demo, the git-hook vector (malice in .husky/pre-commit).
#   3 (CLEAR)   gate MUST NOT block benign-skill (presence != malice, a legit bundled test is not a finding).
#   4 (COVERAGE) HARD: SkillSpector's carrier coverage, pinned in BOTH directions. It is not blind and it
#               is not advisory: it gates on exit code (exit 1 above risk_score 50), and it DOES block
#               gecko-demo, the .test.ts carrier, at 73/100 (HIGH, DO NOT INSTALL). It does NOT block
#               gecko-hook-demo, the .husky/pre-commit carrier, at 28/100 (CAUTION, exit 0), even though
#               it finds the same payload there (PE3 credential access, 90% confidence): it classifies the
#               hook as Executable=No. So a CI pipeline that trusts exit codes ships the git-hook skill
#               with SkillSpector alone. The gate blocks both carriers. Asserting both halves means a
#               change in EITHER direction goes red and we re-measure before touching the docs. (The
#               research SOTA excludes the surface entirely by scope: arXiv 2601.10338 scans SKILL.md +
#               invoked scripts; 2607.02357 detonates the agent path, not `npm test`.)
#   5 (BLOCK)   gate MUST block config-injection-demo, the agent's own auto-run config (CVE-2025-59536).
#   6 (CLEAR)   gate MUST NOT block config-injection-benign (npx MCP + an innocuous hook warn, do not fail).
#   7 (BLOCK)   gate MUST block memory-poisoning-demo, a write to persistent agent memory (Snyk ToxicSkills).
#   8 (BLOCK)   gate MUST block sibling-config-demo: a Cursor MCP command mutated to exfiltrate a
#               credential (CVE-2025-54136 class), a Cursor hook that decodes and execs, and a VS Code
#               task set to run on folder open with its terminal hidden (github.com/microsoft/vscode
#               issue 309406). Confirms findings are attributed to all three files, not just one.
#   9 (CLEAR)   gate MUST NOT block config-injection-benign, extended with a benign Cursor MCP server
#               (npx, warns), a benign Cursor hook, and a visible (non-silent) VS Code folderOpen task.
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
echo "== 4. carrier coverage (HARD): the gate blocks both carriers, SkillSpector blocks only one =="
# The gate must exit nonzero (enforce) on the git-hook vector.
if gate gecko-hook-demo >/dev/null 2>&1; then gate_enforces=0; else gate_enforces=1; fi
# SkillSpector must BLOCK the .test.ts carrier (73/100) and CLEAR the .husky/ carrier (28/100), even though
# it finds the same payload in both. Pin both halves: if either flips, its coverage moved and the docs that
# quote these numbers need re-measuring before they are trusted again.
if ss gecko-demo;      then ss_blocks_testfile=0; else ss_blocks_testfile=1; fi
if ss gecko-hook-demo; then ss_blocks_hook=0;     else ss_blocks_hook=1; fi
if [ "$gate_enforces" -eq 1 ] && [ "$ss_blocks_hook" -eq 0 ] && [ "$ss_blocks_testfile" -eq 1 ]; then
  echo "  PASS: SkillSpector blocks the .test.ts carrier and clears the .husky/ one; the gate blocks both."
  echo "        An exit-code CI gate would let the git-hook skill through with SkillSpector alone."
else
  echo "  FAIL: expected gate=1 ss_hook=0 ss_testfile=1; got gate=$gate_enforces ss_hook=$ss_blocks_hook ss_testfile=$ss_blocks_testfile."
  echo "        SkillSpector's carrier coverage changed. Re-measure both fixtures, then fix docs/ to match."; fail=1
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
echo "== 8. gate MUST block the sibling-ecosystem vector (sibling-config-demo): Cursor MCP, Cursor hooks, VS Code tasks =="
sib_out="$(gate sibling-config-demo 2>&1)"; sib_rc=$?
echo "$sib_out"
if [ "$sib_rc" -eq 0 ]; then
  echo "  FAIL: not blocked"; fail=1
else
  missing=""
  [[ "$sib_out" == *".cursor/mcp.json"* ]]   || missing="$missing .cursor/mcp.json"
  [[ "$sib_out" == *".cursor/hooks.json"* ]] || missing="$missing .cursor/hooks.json"
  [[ "$sib_out" == *".vscode/tasks.json"* ]] || missing="$missing .vscode/tasks.json"
  if [ -n "$missing" ]; then
    echo "  FAIL: blocked, but the output never names:$missing (a sibling glob may have stopped matching)"; fail=1
  else
    echo "  PASS: blocked, with findings attributed to all three sibling files (Cursor MCP, Cursor hooks, VS Code tasks)"
  fi
fi

echo ""
echo "== 9. gate MUST NOT block benign config, including the extended Cursor/VS Code files (config-injection-benign) =="
if gate config-injection-benign; then echo "  PASS: not blocked (npx MCP, innocuous hooks, and a visible folderOpen task all warn or clear, none fail)"; else echo "  FAIL: false positive on standard sibling-ecosystem config"; fail=1; fi

echo ""
if [ "$fail" -eq 0 ]; then echo "PROOF-FIXTURE PASSED: the gate covers the developer-execution surface (test-file, git-hook, config-injection, memory-poisoning, and sibling-ecosystem vectors)."; else echo "PROOF-FIXTURE FAILED"; fi
exit "$fail"
