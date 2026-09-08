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
[ "${1:-}" = "--fail-on-drift" ] && FAIL_ON_DRIFT=1
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
check pip-audit       "$(pinned pip-audit)"       "$(pypi_latest pip-audit)"
check snyk-agent-scan "$(pinned snyk-agent-scan)" "$(pypi_latest snyk-agent-scan)"
check zizmor          "$(pinned zizmor)"          "$(pypi_latest zizmor)"
check actionlint      "$(pinned actionlint)"      "$(gh_latest rhysd/actionlint)"
check semgrep         "$(pinned semgrep)"         "$(pypi_latest semgrep)"
check checkov         "$(pinned checkov)"         "$(pypi_latest checkov)"

# SkillSpector is pinned by commit (no releases upstream) — compare against HEAD.
ss_pinned="$(pinned skillspector)"
ss_head="$(gh api repos/NVIDIA/SkillSpector/commits/HEAD --jq '.sha' 2>/dev/null)"
if [ -z "$ss_head" ]; then
  echo "  skillspector: could not resolve upstream HEAD (skipped)"
elif [ "${ss_head:0:12}" != "${ss_pinned:0:12}" ]; then
  # Reported but deliberately NOT counted as drift. SkillSpector publishes no
  # releases, so it is pinned by commit and moves on every upstream push. Failing
  # on that would keep this gate permanently red no matter what anyone did, which
  # is precisely the cry-wolf signal it exists to avoid. Weigh it against the
  # upstream changelog and bump deliberately, not on sight.
  echo "::warning::skillspector pinned at ${ss_pinned:0:12} but upstream HEAD is ${ss_head:0:12} — bump SKILLSPECTOR_REF and tools.lock if the changelog warrants it (advisory: does not fail this check)."
  row "skillspector" "${ss_pinned:0:12}" "${ss_head:0:12}" "behind (advisory, tracks HEAD)"
else
  echo "  skillspector: up to date (${ss_pinned:0:12})"
  row "skillspector" "${ss_pinned:0:12}" "${ss_head:0:12}" "current"
fi

# SkillSpector tracks HEAD, so it drifts on any upstream commit. That is expected
# noise rather than a signal to bump on sight; weigh it against the changelog.
if [ "$DRIFTED" -eq 1 ] && [ "$FAIL_ON_DRIFT" -eq 1 ]; then
  [ -n "$SUMMARY" ] && {
    echo "" >> "$SUMMARY"
    echo "Bump \`toolbox/tools.lock\` and the matching Dockerfile ARG together, then let the build gate rebuild and rescan." >> "$SUMMARY"
  }
  echo "::error::pinned tools have drifted from upstream (see the table above)."
  exit 3
fi
exit 0
