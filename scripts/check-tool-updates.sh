#!/usr/bin/env bash
# Compare the tool versions pinned in toolbox/tools.lock against the latest
# available upstream, emitting GitHub Actions warnings when a newer version
# exists. Non-blocking: an informational drift signal for the weekly build.
#
# Requires: gh (with GH_TOKEN), curl, python3 — all present on GitHub runners.
set -uo pipefail

lock="$(dirname "$0")/../toolbox/tools.lock"

pinned() { grep -E "^$1[[:space:]]" "$lock" | awk '{print $2}'; }

gh_latest() { gh api "repos/$1/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//'; }

pypi_latest() {
  curl -fsSL "https://pypi.org/pypi/$1/json" 2>/dev/null \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['info']['version'])" 2>/dev/null
}

check() { # name current latest
  local name="$1" cur="$2" latest="$3"
  if [ -z "$latest" ]; then
    echo "  $name: could not resolve latest (skipped)"
  elif [ "$cur" != "$latest" ]; then
    echo "::warning::$name pinned at $cur but $latest is available — bump toolbox/tools.lock and the matching Dockerfile ARG."
  else
    echo "  $name: up to date ($cur)"
  fi
}

echo "Checking pinned tool versions against upstream..."
check gitleaks        "$(pinned gitleaks)"        "$(gh_latest gitleaks/gitleaks)"
check trufflehog      "$(pinned trufflehog)"      "$(gh_latest trufflesecurity/trufflehog)"
check osv-scanner     "$(pinned osv-scanner)"     "$(gh_latest google/osv-scanner)"
check syft            "$(pinned syft)"            "$(gh_latest anchore/syft)"
check pip-audit       "$(pinned pip-audit)"       "$(pypi_latest pip-audit)"
check snyk-agent-scan "$(pinned snyk-agent-scan)" "$(pypi_latest snyk-agent-scan)"
