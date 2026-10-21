#!/usr/bin/env bash
# Compare the tool versions pinned in toolbox/tools.lock against the latest
# available upstream.
#
# These tools are pinned by download URL and commit SHA, not by a package
# manifest, so Dependabot cannot see any of them. This script is the only thing
# that can. It ran weekly and non-blocking for months while nine of eleven pins
# drifted, until one of them (a CVE in a vendored Go binary) broke the build:
# a warning on a green job reads exactly like no warning at all.
#
# So it now has two modes. Default stays advisory for local use. --fail-on-drift
# exits 3 when anything is behind, which is what CI runs, and it writes a table
# to $GITHUB_STEP_SUMMARY so the state is legible without opening a log.
#
# Requires: gh (with GH_TOKEN), curl, python3 — all present on GitHub runners.
set -uo pipefail

FAIL_ON_DRIFT=0
EMIT_DRIFT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fail-on-drift) FAIL_ON_DRIFT=1 ;;
    # Machine-readable drift for scripts/apply-tool-bumps.py: one
    # "name<TAB>pinned<TAB>latest" row per behind tool. Separate from the human
    # output on purpose, so the bump automation never has to parse a log.
    --emit-drift)
      EMIT_DRIFT="${2:-}"
      [ -n "$EMIT_DRIFT" ] || { echo "--emit-drift needs a file path" >&2; exit 2; }
      shift
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
# Truncate up front so a run that finds no drift leaves an empty file rather
# than yesterday's rows.
[ -n "$EMIT_DRIFT" ] && : > "$EMIT_DRIFT"
DRIFTED=0
SUMMARY="${GITHUB_STEP_SUMMARY:-}"
[ -n "$SUMMARY" ] && {
  echo "## Pinned tool drift" >> "$SUMMARY"
  echo "" >> "$SUMMARY"
  echo "| Tool | Pinned | Latest | Status |" >> "$SUMMARY"
  echo "|---|---|---|---|" >> "$SUMMARY"
}
row() { [ -n "$SUMMARY" ] && echo "| $1 | \`$2\` | \`$3\` | $4 |" >> "$SUMMARY"; }

lock="$(dirname "$0")/../toolbox/tools.lock"

# A tool can be listed once per image that ships it (semgrep appears under both
# skill-audit and sast), so collapse to unique values. Two DIFFERENT versions for
# one tool is itself a defect, and is reported rather than silently taking one.
pinned() {
  local vals; vals="$(grep -E "^$1[[:space:]]" "$lock" | awk '{print $2}' | sort -u)"
  if [ "$(printf '%s
' "$vals" | grep -c .)" -gt 1 ]; then
    echo "::error::$1 is pinned to more than one version in tools.lock: $(printf '%s' "$vals" | tr '
' ' ')" >&2
    DRIFTED=1
  fi
  printf '%s
' "$vals" | head -1
}

gh_latest() { gh api "repos/$1/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//'; }

pypi_latest() {
  curl -fsSL "https://pypi.org/pypi/$1/json" 2>/dev/null \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['info']['version'])" 2>/dev/null
}

check() { # name current latest
  local name="$1" cur="$2" latest="$3"
  if [ -z "$latest" ]; then
    # Unresolvable upstream is not drift, but it is not a clean check either:
    # say so loudly rather than letting a network blip read as "up to date".
    echo "::warning::$name: could not resolve the latest version upstream (check skipped, NOT verified current)."
    row "$name" "$cur" "?" "could not resolve"
  elif [ "$cur" != "$latest" ]; then
    echo "::warning::$name pinned at $cur but $latest is available — bump toolbox/tools.lock and the matching Dockerfile ARG."
    row "$name" "$cur" "$latest" "**behind**"
    [ -n "$EMIT_DRIFT" ] && printf '%s\t%s\t%s\n' "$name" "$cur" "$latest" >> "$EMIT_DRIFT"
    DRIFTED=1
  else
    echo "  $name: up to date ($cur)"
    row "$name" "$cur" "$latest" "current"
  fi
}

echo "Checking pinned tool versions against upstream..."
check betterleaks     "$(pinned betterleaks)"     "$(gh_latest betterleaks/betterleaks)"
check trufflehog      "$(pinned trufflehog)"      "$(gh_latest trufflesecurity/trufflehog)"
check osv-scanner     "$(pinned osv-scanner)"     "$(gh_latest google/osv-scanner)"
check syft            "$(pinned syft)"            "$(gh_latest anchore/syft)"
check pip             "$(pinned pip)"             "$(pypi_latest pip)"
check pip-audit       "$(pinned pip-audit)"       "$(pypi_latest pip-audit)"
check snyk-agent-scan "$(pinned snyk-agent-scan)" "$(pypi_latest snyk-agent-scan)"
check zizmor          "$(pinned zizmor)"          "$(pypi_latest zizmor)"
check actionlint      "$(pinned actionlint)"      "$(gh_latest rhysd/actionlint)"
check semgrep         "$(pinned semgrep)"         "$(pypi_latest semgrep)"
check checkov         "$(pinned checkov)"         "$(pypi_latest checkov)"

# SkillSpector: a hard check, like every other tool, against the latest RELEASE.
#
# This used to be advisory. The old reasoning was that SkillSpector "publishes no
# releases", so the pin tracked HEAD and moved on every upstream push; failing on
# that would have kept this gate permanently red no matter what anyone did. That
# premise expired — upstream has tagged releases roughly monthly since v2.10.0 —
# and the exemption outlived it. A warning that cannot fail is a warning nobody
# acts on: skillspector sat eight releases behind while every other pin in this
# file was bumped twice.
#
# Deliberately NOT written to --emit-drift. That file is the auto-bump queue, and a
# SkillSpector bump is not mechanical: it changes measured scanner behaviour that
# tests/gate-proof.sh hard-asserts and that docs/ quote by number, so a human has to
# re-measure the fixtures first. apply-tool-bumps.py would also half-apply it — the
# ARG is SKILLSPECTOR_REF, not SKILLSPECTOR_VERSION, so patch_lock() would rewrite
# tools.lock, patch_dockerfiles() would match nothing, and the bump would report
# success while the image still installed the old commit.
ss_pinned="$(pinned skillspector)"
ss_latest="$(gh_latest NVIDIA/SkillSpector)"
if [ -z "$ss_latest" ]; then
  echo "::warning::skillspector: could not resolve the latest release upstream (check skipped, NOT verified current)."
  row "skillspector" "$ss_pinned" "?" "could not resolve"
elif [ "$ss_pinned" != "$ss_latest" ]; then
  echo "::warning::skillspector pinned at $ss_pinned but $ss_latest is available — bump tools.lock and SKILLSPECTOR_REF together, then re-measure tests/fixtures (docs/threats/developer-execution.md)."
  row "skillspector" "$ss_pinned" "$ss_latest" "**behind** (bump by hand)"
  DRIFTED=1
else
  echo "  skillspector: up to date ($ss_pinned)"
  row "skillspector" "$ss_pinned" "$ss_latest" "current"
fi

# The lock records the version, the Dockerfile ARG records the bytes, and nothing
# else checks that they still describe the same commit. A half-bump reads as green.
ss_ref="$(sed -n 's/^ARG SKILLSPECTOR_REF=\([0-9a-f]\{40\}\).*/\1/p' \
  "$(dirname "$0")/../toolbox/skill-audit/Dockerfile" | head -1)"
ss_tag_sha="$(gh api "repos/NVIDIA/SkillSpector/commits/v${ss_pinned}" --jq '.sha' 2>/dev/null)"
if [ -z "$ss_ref" ]; then
  echo "::warning::skillspector: could not read SKILLSPECTOR_REF from toolbox/skill-audit/Dockerfile (lock/ARG agreement NOT verified)."
elif [ -z "$ss_tag_sha" ]; then
  echo "::warning::skillspector: could not resolve tag v${ss_pinned} upstream (lock/ARG agreement NOT verified)."
elif [ "$ss_ref" != "$ss_tag_sha" ]; then
  echo "::error::skillspector: tools.lock says ${ss_pinned} (v${ss_pinned} = ${ss_tag_sha:0:12}) but SKILLSPECTOR_REF is ${ss_ref:0:12}. The record and the installed bytes disagree."
  DRIFTED=1
fi

if [ "$DRIFTED" -eq 1 ] && [ "$FAIL_ON_DRIFT" -eq 1 ]; then
  [ -n "$SUMMARY" ] && {
    echo "" >> "$SUMMARY"
    echo "Bump \`toolbox/tools.lock\` and the matching Dockerfile ARG together, then let the build gate rebuild and rescan." >> "$SUMMARY"
  }
  echo "::error::pinned tools have drifted from upstream (see the table above)."
  exit 3
fi
exit 0
