#!/usr/bin/env bash
# skill-testfile-gate — flag developer-execution-surface files bundled inside an agent
# skill. Files like *.test.ts, *.spec.js, conftest.py, *.config.js and __tests__/ are
# auto-discovered and executed by the DEVELOPER's test runner (Jest / Vitest / pytest)
# with full local permissions — no agent involved. That is precisely the surface every
# published skill scanner ignores (Gecko Security, 2026; see docs/threat-model.md).
#
# This is the repo's first-party contribution: the "covered surface" (SKILL.md, agent-
# invoked scripts) is handled by SkillSpector; this gate covers the surface it does not.
#
# Usage: skill-testfile-gate [PATH]      (default: current directory)
# Exit:  0 = clean, 1 = execution-surface files found (use to gate/block).
set -uo pipefail

TARGET="${1:-.}"
found=0

scan_dir() {
  local root="$1" label="$2"
  [ -d "$root" ] || return 0
  while IFS= read -r f; do
    echo "::warning::[$label] developer-execution-surface file bundled in a skill: $f"
    found=$((found + 1))
  done < <(find "$root" \( \
        -name '*.test.*' -o -name '*.spec.*' -o -name 'conftest.py' \
        -o -name '*.config.js' -o -name '*.config.ts' -o -name '*.config.mjs' \
        -o -type d -name '__tests__' \
      \) 2>/dev/null)
}

# Installed skills land in these committed, team-shared directories.
for d in .agents .claude .cursor; do
  scan_dir "$TARGET/$d" "$d"
done

# A standalone skill package (a SKILL.md at its root): scan it directly.
if [ -f "$TARGET/SKILL.md" ]; then
  scan_dir "$TARGET" "skill-package"
fi

if [ "$found" -gt 0 ]; then
  echo "::error::skill-testfile-gate: ${found} developer-execution-surface file(s) found."
  echo "They run via the test runner (not the agent) with full local perms and sit outside every skill scanner."
  echo "Mitigate: review before install; pin the skill to a commit; exclude skill dirs (.agents/.claude/.cursor) from test-runner globs."
  exit 1
fi
echo "skill-testfile-gate: clean — no bundled test/config execution-surface files under ${TARGET}."
