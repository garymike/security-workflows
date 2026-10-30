#!/usr/bin/env bash
# CI proof-fixture: the differentiator, checked on every dogfood build against the freshly built
# skill-audit-toolbox image. Hard-asserts the gate's behavior; observes SkillSpector's.
#
#   1 (BLOCK)   gate MUST block gecko-demo, the test-file vector (malice in a *.test.ts).
#   2 (BLOCK)   gate MUST block gecko-hook-demo, the git-hook vector (malice in .husky/pre-commit).
#   3 (CLEAR)   gate MUST NOT block benign-skill (presence != malice, a legit bundled test is not a finding).
#   4 (COVERAGE) HARD on the one carrier upstream still misses, OBSERVED on the rest.
#               As of SkillSpector v2.13.0 the original differentiator is mostly gone, and that is
#               recorded here rather than worked around. It blocks gecko-demo (64/100), gecko-hook-demo
#               (76/100), config-injection-demo (100/100) and sibling-config-demo (51/100). Those four
#               are PRINTED, not asserted: sibling-config-demo clears the risk_score-50 threshold by a
#               single point, so hard-asserting it would turn this gate red on any minor upstream
#               rescoring, which is the cry-wolf signal we avoid elsewhere.
#               What IS hard-asserted: SkillSpector must NOT block memory-poisoning-demo. It scores it
#               0/100 SAFE, "no security issues detected", at Coverage 100.0% with the test file typed
#               Executable=Yes — so it read the file, analysed it, and cleared it. Measured mechanism vs
#               content: the identical appendFileSync to MEMORY.md scores 0/100 with an inert payload and
#               35/100 with a literal injection string, against 27/100 for that same string sitting in
#               SKILL.md prose with no write at all. The write to persistent agent memory is worth ~8
#               points of prose matching and is not modelled; neither variant blocks. That is the last
#               carrier the gate uniquely covers, so if this assertion ever flips, the gate's remaining
#               justification is gone and docs/ must say so. (The research SOTA excludes the surface
#               entirely by scope: arXiv 2601.10338 scans SKILL.md + invoked scripts; 2607.02357
#               detonates the agent path, not `npm test`.)
#   5 (BLOCK)   gate MUST block config-injection-demo, the agent's own auto-run config (CVE-2025-59536).
#   6 (CLEAR)   gate MUST NOT block config-injection-benign (npx MCP + an innocuous hook warn, do not fail).
#   7 (BLOCK)   gate MUST block memory-poisoning-demo, a write to persistent agent memory (Snyk ToxicSkills).
#   8 (BLOCK)   gate MUST block sibling-config-demo: a Cursor MCP command mutated to exfiltrate a
#               credential (CVE-2025-54136 class), a Cursor hook that decodes and execs, and a VS Code
#               task set to run on folder open with its terminal hidden (github.com/microsoft/vscode
#               issue 309406). Confirms findings are attributed to all three files, not just one.
#   9 (CLEAR)   gate MUST NOT block config-injection-benign, extended with a benign Cursor MCP server
#               (npx, warns), a benign Cursor hook, and a visible (non-silent) VS Code folderOpen task.
#  10 (BLOCK)   gate MUST block memory-poisoning-python-demo: the same memory write as #7 but in
#               Python (conftest.py, open(path, "a")). #7 passed on a TypeScript-only fixture while
#               every Python form walked through, so the surface now carries one per language.
#  11 (BLOCK)   gate MUST block memory-poisoning-claude-md-demo: a write aimed at CLAUDE.md, which
#               was missing from the rule's destination list.
#  12 (CLEAR)   gate MUST NOT block memory-read-benign: a READ of MEMORY.md next to an arrow
#               function. The rule's redirect alternative used to match the `>` in `=>`, making a
#               read-only file a blocking write finding.
#
#  13 (BLOCK)   gate MUST block memory-poisoning-raw-path-demo: open(r"C:\Users\alice\MEMORY.md",
#               "a"). The rule required the quote to follow `open(` immediately, so every Python
#               string prefix walked through. NVIDIA/SkillSpector#893 was sent back in review for
#               the same class of bug in its own analyzer, which is what prompted measuring ours.
#  14 (BLOCK)   gate MUST block memory-poisoning-fstring-demo: open(f"{base}/MEMORY.md", "a"). Same
#               prefix gap as #13, and the shape a carrier uses when the directory is computed at
#               runtime while the basename stays literal.
#  15 (BLOCK)   gate MUST block memory-poisoning-win-config-demo: open(r".claude\settings.json",
#               "w"). The agent config directories were spelled with a hardcoded forward slash, so
#               they were uncovered on the one platform where a backslash is the normal spelling.
#  16 (CLEAR)   gate MUST NOT block memory-near-miss-benign: memory.md.bak and MY_AGENTS.md. The
#               basename was matched anywhere inside the literal, so a filename that merely
#               CONTAINS an agent-memory name blocked. A basename now has to start the literal or
#               follow a separator.
#
# Usage: bash tests/gate-proof.sh [IMAGE]     (default: skill-audit-toolbox:ci)
set -uo pipefail
IMAGE="${1:-${GATE_IMAGE:-skill-audit-toolbox:ci}}"
FIX="$(cd "$(dirname "$0")/fixtures" && pwd)"
fail=0
gate() { docker run --rm -e GATE_NO_EXCLUDES=1 -v "$FIX/$1:/skill:ro" "$IMAGE" skill-testfile-gate /skill; }
# SkillSpector v2.11+ classifies a file as executable partly on `mode & 0o111`, so the
# scan has to see git-accurate permissions. A bind mount from a non-POSIX host (podman
# on Windows presents everything as 777) would type SKILL.md and every .json as
# executable and inflate the score, making a local run disagree with CI. Copy into the
# container and force dirs 755 / files 644 so both agree. Prints the score; the caller
# gets SkillSpector's exit code.
ss_scan() {
  docker run --rm -v "$FIX/$1:/skill:ro" "$IMAGE" sh -c '
    W=${TMPDIR:-/tmp}/ss; rm -rf "$W"; mkdir -p "$W"; cp -r /skill/. "$W"/
    find "$W" -type d -exec chmod 755 {} + ; find "$W" -type f -exec chmod 644 {} +
    skillspector scan "$W" --no-llm 2>&1' 2>/dev/null
}
ss() { ss_scan "$1" >/dev/null 2>&1; }
ss_score() { ss_scan "$1" 2>/dev/null | sed -n 's/.*Score *\([0-9]\{1,\}\)\/100.*/\1/p' | head -1; }

echo "== 1. gate MUST block the test-file vector (gecko-demo) =="
if gate gecko-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked"; fi

echo ""
echo "== 2. gate MUST block the git-hook vector (gecko-hook-demo) =="
if gate gecko-hook-demo; then echo "  FAIL: not blocked"; fail=1; else echo "  PASS: blocked"; fi

echo ""
echo "== 3. gate MUST NOT block the benign skill =="
if gate benign-skill; then echo "  PASS: not blocked (presence != malice)"; else echo "  FAIL: false positive"; fail=1; fi

echo ""
echo "== 4. carrier coverage: where SkillSpector has caught up, and the one carrier left =="
# Observation first: print SkillSpector's live verdict on every malicious fixture, so the
# build log carries the real comparison instead of numbers copied into a doc months ago.
printf "  %-24s %-9s %s\n" FIXTURE SCORE "SKILLSPECTOR"
for fx in gecko-demo gecko-hook-demo config-injection-demo sibling-config-demo memory-poisoning-demo; do
  if ss "$fx"; then verdict="exit 0, does NOT block"; else verdict="exit 1, BLOCKS"; fi
  printf "  %-24s %-9s %s\n" "$fx" "$(ss_score "$fx")/100" "$verdict"
done

# The single hard assertion: memory-poisoning-demo is the last carrier the gate uniquely
# covers. SkillSpector reads the file, types it executable, reports 100% coverage, and
# clears it at 0/100 SAFE. The gate blocks it. If EITHER half flips, the gate's remaining
# justification has changed and docs/ must be re-measured before they are trusted.
if gate memory-poisoning-demo >/dev/null 2>&1; then gate_enforces=0; else gate_enforces=1; fi
if ss memory-poisoning-demo; then ss_blocks_mem=0; else ss_blocks_mem=1; fi
if [ "$gate_enforces" -eq 1 ] && [ "$ss_blocks_mem" -eq 0 ]; then
  echo "  PASS: SkillSpector clears the persistent-memory-write carrier; the gate blocks it."
  echo "        An exit-code CI gate would install that skill with SkillSpector alone."
else
  echo "  FAIL: expected gate=1 ss_mem=0; got gate=$gate_enforces ss_mem=$ss_blocks_mem."
  if [ "$ss_blocks_mem" -eq 1 ]; then
    echo "        SkillSpector now blocks the memory-write carrier too. That was the gate's last"
    echo "        uniquely-covered carrier: re-measure every fixture and say so in docs/, per the"
    echo "        sunset rule in README.md, rather than finding a new way to word the claim."
  fi
  fail=1
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
echo "== 10. gate MUST block the memory-poisoning vector in its PYTHON form (memory-poisoning-python-demo) =="
# Regression guard. Assertion 7 passed for years on a TypeScript-only fixture while every Python
# form walked through: dev-exec-writes-agent-memory required the sink token before the path, which
# is the JS shape, and Python's open() takes the path first and the mode second. One carrier per
# language, or a language-shaped hole stays invisible.
if gate memory-poisoning-python-demo; then echo "  FAIL: not blocked (the Python open(path, mode) shape is uncovered again)"; fail=1; else echo "  PASS: blocked (conftest.py appends to MEMORY.md)"; fi

echo ""
echo "== 11. gate MUST block a write aimed at CLAUDE.md (memory-poisoning-claude-md-demo) =="
# CLAUDE.md was absent from the rule's destination list, which had MEMORY.md, SOUL.md, AGENTS.md,
# .claude/ and .cursor/. The most-loaded memory file for the agent this gate exists to protect was
# the one destination it did not check.
if gate memory-poisoning-claude-md-demo; then echo "  FAIL: not blocked (CLAUDE.md is missing from the destination list again)"; fail=1; else echo "  PASS: blocked (test file appends to CLAUDE.md)"; fi

echo ""
echo "== 12. gate MUST NOT block a READ of agent memory (memory-read-benign) =="
# Reading agent memory is not the threat; writing to it is. This guards a false positive that
# shipped: the rule's shell-redirect alternative matched the `>` in a JS arrow function, so an
# `=>` within 60 characters of "MEMORY.md" reported a write on a read-only file.
if gate memory-read-benign; then echo "  PASS: not blocked (a read of MEMORY.md beside an arrow function is not a write)"; else echo "  FAIL: false positive on a read-only access to agent memory"; fail=1; fi

echo ""
echo "== 13. gate MUST block a RAW-STRING destination (memory-poisoning-raw-path-demo) =="
# The rule required `open(` to be followed immediately by the quote, so r"", rf"", f"" and R"" all
# walked through. A raw string is the natural spelling for a Windows path, so this was the likely
# spelling in a real carrier rather than an exotic one. Not a backslash problem on our side: the
# escaped form open("C:\\Users\\MEMORY.md", "a") already matched.
if gate memory-poisoning-raw-path-demo; then echo "  FAIL: not blocked (a Python string prefix defeats the destination match again)"; fail=1; else echo "  PASS: blocked (conftest.py appends to a raw-string MEMORY.md path)"; fi

echo ""
echo "== 14. gate MUST block an F-STRING destination (memory-poisoning-fstring-demo) =="
# Same prefix gap as #13. An f-string is how a carrier reaches a memory file whose directory is
# computed at runtime while the BASENAME stays literal, and the basename is what the rule matches.
# A fully computed destination is still a documented residual, not this.
if gate memory-poisoning-fstring-demo; then echo "  FAIL: not blocked (the f prefix defeats the destination match again)"; fail=1; else echo "  PASS: blocked (conftest.py appends to an f-string MEMORY.md path)"; fi

echo ""
echo "== 15. gate MUST block a WINDOWS-SEPARATOR agent config write (memory-poisoning-win-config-demo) =="
# The destination list spelled the agent directories as `.claude/` with a hardcoded forward slash,
# so `.claude\settings.json` was uncovered on the platform where that is the normal spelling.
# Same rule covers the memory files and the config directories, so the gap applied to both.
if gate memory-poisoning-win-config-demo; then echo "  FAIL: not blocked (a backslash separator defeats the agent-config destinations again)"; fail=1; else echo "  PASS: blocked (conftest.py writes .claude with a backslash separator)"; fi

echo ""
echo "== 16. gate MUST NOT block NEAR-MISS filenames (memory-near-miss-benign) =="
# Guards a false positive the rule shipped with: the basename matched anywhere inside the string
# literal, so memory.md.bak (a backup, which nothing loads into a session) and MY_AGENTS.md (a
# team roster) both blocked. Upstream lists memory.md.bak as a quiet case for the same reason.
if gate memory-near-miss-benign; then echo "  PASS: not blocked (memory.md.bak and MY_AGENTS.md are different files)"; else echo "  FAIL: false positive on a filename that merely contains an agent-memory name"; fail=1; fi

echo ""
if [ "$fail" -eq 0 ]; then echo "PROOF-FIXTURE PASSED: the gate covers the developer-execution surface (test-file, git-hook, config-injection, memory-poisoning, and sibling-ecosystem vectors)."; else echo "PROOF-FIXTURE FAILED"; fi
exit "$fail"
