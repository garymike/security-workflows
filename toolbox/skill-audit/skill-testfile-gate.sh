#!/usr/bin/env bash
# skill-testfile-gate — review the DEVELOPER-execution surface of an agent skill.
#
# The surface no published skill scanner covers: files a skill bundles that are auto-executed by
# the DEVELOPER's toolchain — the test runner (Jest/Vitest/Mocha/pytest), the package manager
# (npm lifecycle scripts), git (hooks), or the interpreter (.pth/sitecustomize) — with full local
# permissions, entirely outside the agent (Gecko Security, 2026; see docs/threat-model.md). The
# "covered surface" (SKILL.md, agent-invoked scripts) is SkillSpector's job; this gate covers the
# one it does not.
#
# Two layers, tiered by severity (docs/adr/0012):
#   • Inventory (low)   — an auto-executed skill file is PRESENT. Reported, not blocking by default:
#                         legitimate skills ship tests, so presence alone is a signal, not a verdict.
#   • Malice (high)     — that file DOES something hostile (credential read, curl|bash, reverse shell,
#                         decode-and-exec, agent-memory write, obfuscation). Blocks. Detected by the
#                         bundled Semgrep rule pack (rules/agent-exec-surface.yml) + an invisible-Unicode
#                         check. Static rules are a cheap pre-filter, not a trust gate — an adaptive
#                         author can obfuscate past them (SkillCloak, arXiv 2607.02357), which is why
#                         WARNING findings are flagged to ESCALATE to a sandboxed (Tier-2) run.
#
# Scope (authoritative skill locations, code.claude.com/docs/en/skills#where-skills-live): personal/
# project/plugin/enterprise + nested `**/.claude/skills/` (monorepo) + `.claude/commands/` + `.cursor`/
# `.agents` (cross-agent) + symlinked skill dirs. Also reads what other scanners are blind to: git
# hooks under `.git/hooks` (SkillCloak Table I: 8/9 scanners skip `.git/`).
#
# Usage: skill-testfile-gate [PATH]        (default: current directory)
# Env:   GATE_RULES            path to the Semgrep rule pack (default: bundled in image)
#        GATE_SARIF            if set, write the malice-layer SARIF here (for code-scanning upload)
#        GATE_FAIL_ON_MALICE   block on ERROR findings (default: true)
#        GATE_FAIL_ON_INVENTORY block on mere presence (default: false)
# Exit:  0 = clean / inventory-only, 1 = malice (or inventory when GATE_FAIL_ON_INVENTORY=true), 2 = usage.
set -uo pipefail

TARGET="${1:-.}"
RULES="${GATE_RULES:-/usr/local/share/skill-audit/agent-exec-surface.yml}"
SARIF_OUT="${GATE_SARIF:-}"
FAIL_ON_MALICE="${GATE_FAIL_ON_MALICE:-true}"
FAIL_ON_INVENTORY="${GATE_FAIL_ON_INVENTORY:-false}"

warn() { echo "::warning::$*"; }
err()  { echo "::error::$*"; }
note() { echo "$*"; }

[ -e "$TARGET" ] || { err "skill-testfile-gate: target not found: $TARGET"; exit 2; }

# Always skip dependency trees; also skip test-fixture/test-data dirs unless GATE_NO_EXCLUDES=1
# (the CI proof-fixture sets it to scan the intentional demo skills under tests/fixtures/).
PRUNE=( -path '*/node_modules/*' -o -path '*/.venv/*' -o -path '*/venv/*' -o -path '*/.git/objects/*' )
excluded() {
  case "$1" in */node_modules/*|*/.venv/*|*/venv/*|*/.git/objects/*) return 0;; esac
  if [ "${GATE_NO_EXCLUDES:-0}" != "1" ]; then
    case "$1" in */tests/fixtures/*|*/test/fixtures/*|*/testdata/*|*/__fixtures__/*) return 0;; esac
  fi
  return 1
}

# --- 1. Skill roots to inspect (symlinks followed: a skill dir can be symlinked in) ---
roots=()
while IFS= read -r d; do excluded "$d" || roots+=("$d"); done < <(
  find -L "$TARGET" \( "${PRUNE[@]}" \) -prune -o -type d \( -name '.claude' -o -name '.cursor' -o -name '.agents' \) -print 2>/dev/null)
while IFS= read -r f; do excluded "$f" || roots+=("$(dirname "$(dirname "$f")")"); done < <(
  find -L "$TARGET" \( "${PRUNE[@]}" \) -prune -o -type f -path '*/.claude-plugin/plugin.json' -print 2>/dev/null)
while IFS= read -r f; do excluded "$f" || roots+=("$(dirname "$f")"); done < <(
  find -L "$TARGET" \( "${PRUNE[@]}" \) -prune -o -type f -name 'SKILL.md' -print 2>/dev/null)
[ "${#roots[@]}" -gt 0 ] && mapfile -t roots < <(printf '%s\n' "${roots[@]}" | sort -u)
[ "${#roots[@]}" -eq 0 ] && roots=("$TARGET")   # fall back to scanning the target itself

# --- 2. Inventory: developer-execution-surface files within those roots ---
raw=()
while IFS= read -r f; do raw+=("$f"); done < <(
  find -L "${roots[@]}" \( "${PRUNE[@]}" \) -prune -o -type f \( \
      -name '*.test.*' -o -name '*.spec.*' -o -name 'conftest.py' \
      -o -name '*.config.js' -o -name '*.config.ts' -o -name '*.config.mjs' -o -name '*.config.cjs' \
      -o -name '*.setup.js' -o -name '*.setup.ts' -o -name '.mocharc*' \
      -o -name 'sitecustomize.py' -o -name 'usercustomize.py' -o -name '*.pth' -o -name 'setup.py' \
    \) -print 2>/dev/null
  find -L "${roots[@]}" -type d -name '__tests__' -exec find -L {} -type f -print \; 2>/dev/null)
# git hooks + husky (auto-run by git; a scanner blind-spot) — active hooks only.
while IFS= read -r f; do raw+=("$f"); done < <(
  find -L "$TARGET" -type f \( -path '*/.git/hooks/*' -o -path '*/.husky/*' \) ! -name '*.sample' 2>/dev/null)
# package.json only when it declares an auto-run lifecycle script.
while IFS= read -r f; do
  grep -qE '"(pre|post)?install"[[:space:]]*:|"prepare"[[:space:]]*:|"prepublish(Only)?"[[:space:]]*:' "$f" 2>/dev/null \
    && raw+=("$f")
done < <(find -L "${roots[@]}" \( "${PRUNE[@]}" \) -prune -o -type f -name 'package.json' -print 2>/dev/null)

candidates=()
for f in "${raw[@]:-}"; do [ -n "$f" ] && ! excluded "$f" && candidates+=("$f"); done
[ "${#candidates[@]}" -eq 0 ] && { note "skill-testfile-gate: clean — no developer-execution-surface files under ${TARGET}."; exit 0; }
mapfile -t candidates < <(printf '%s\n' "${candidates[@]}" | sort -u)

n=${#candidates[@]}
note "skill-testfile-gate: ${n} developer-execution-surface file(s) present (inventory layer)."
for f in "${candidates[@]}"; do warn "[inventory] auto-executed skill file present (review before install): $f"; done

# --- 3. Malice layer ---
malice=0; suspicious=0

# 3a. Invisible / bidirectional Unicode — a SkillCloak Structural-Obfuscation tell. grep -P is more
#     reliable here than a Semgrep unicode regex.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  err "[malice] invisible/bidirectional Unicode (obfuscation tell): $f"; malice=$((malice + 1))
done < <(grep -lP '[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{FEFF}]' "${candidates[@]}" 2>/dev/null || true)

# 3b. Semgrep rule pack over the candidate files (scope IS the signal).
if command -v semgrep >/dev/null 2>&1 && [ -f "$RULES" ]; then
  sarif="${SARIF_OUT:-$(mktemp)}"
  semgrep scan --config "$RULES" --sarif --output "$sarif" --metrics=off --quiet \
    --disable-version-check "${candidates[@]}" >/dev/null 2>&1 || true
  if [ -s "$sarif" ]; then
    report=$(python3 - "$sarif" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("__COUNTS__ 0 0"); sys.exit(0)
e = w = 0
for run in d.get("runs", []):
    for r in run.get("results", []):
        lvl = r.get("level", "warning")
        msg = (r.get("message", {}).get("text", "") or "").splitlines()
        msg = msg[0] if msg else ""
        loc = (r.get("locations") or [{}])[0].get("physicalLocation", {})
        f = loc.get("artifactLocation", {}).get("uri", "?")
        ln = loc.get("region", {}).get("startLine", "?")
        if lvl == "error":
            e += 1; print(f"::error::[malice] {f}:{ln} {msg}")
        else:
            w += 1; print(f"::warning::[suspicious] {f}:{ln} {msg}")
print(f"__COUNTS__ {e} {w}")
PY
)
    echo "$report" | grep -v '^__COUNTS__' || true
    read -r se sw < <(echo "$report" | grep '^__COUNTS__' | tail -1 | awk '{print $2, $3}')
    malice=$((malice + ${se:-0})); suspicious=$((suspicious + ${sw:-0}))
  fi
  [ -n "$SARIF_OUT" ] || rm -f "$sarif"
else
  warn "semgrep or rule pack unavailable — malice layer skipped (inventory only). Rules: $RULES"
fi

# --- 4. Verdict ---
echo ""
note "skill-testfile-gate summary — inventory: ${n}  suspicious (WARNING): ${suspicious}  malice (ERROR): ${malice}"
rc=0
if [ "$malice" -gt 0 ]; then
  err "skill-testfile-gate: ${malice} malicious pattern(s) on the developer-execution surface."
  note "These files auto-execute via the test runner / package manager / git — outside the agent, with full local permissions. Do NOT install without a sandboxed review."
  [ "$FAIL_ON_MALICE" = "true" ] && rc=1
elif [ "$suspicious" -gt 0 ]; then
  warn "skill-testfile-gate: ${suspicious} suspicious pattern(s) — review, and escalate to a sandboxed run if the skill is untrusted."
fi
if [ "$FAIL_ON_INVENTORY" = "true" ] && [ "$n" -gt 0 ] && [ "$rc" -eq 0 ]; then
  err "skill-testfile-gate: developer-execution-surface files present and GATE_FAIL_ON_INVENTORY=true."; rc=1
fi
note "Mitigate: review before install; pin the skill to a commit; exclude .claude/.cursor/.agents from test-runner globs; run untrusted skills only in an egress-gated sandbox."
exit "$rc"
