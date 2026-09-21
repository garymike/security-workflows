#!/usr/bin/env python3
"""Apply pinned-tool version bumps to tools.lock and the matching Dockerfile ARGs.

Reads the TSV that `check-tool-updates.sh --emit-drift` writes (name, pinned,
latest) and rewrites both places a version lives. Those two must move together:
tools.lock is the record, the Dockerfile ARG is what actually gets installed, and
a bump to one without the other is a lie that survives until someone reads a
build log.

Policy: patch and minor bumps are applied automatically; a major bump is reported
and left alone. Majors carry breaking CLI and ruleset changes that need a human
reading a changelog, and quietly shipping one across six images is how a scanner
starts silently passing everything.

Anything that does not parse as semver is skipped rather than guessed at —
skillspector is pinned by commit SHA and is excluded upstream by the drift check
already, but this stays defensive in case that changes.

Usage: apply-tool-bumps.py <drift.tsv> <repo-root>
Exit:  0 = something changed (or nothing to do), 1 = error.
Writes a markdown summary of what it did to stdout.
"""
import os
import re
import sys


def semver(v):
    """Parse a dotted version into a tuple of ints, or None if it is not semver."""
    if not re.fullmatch(r"\d+(\.\d+)*", v):
        return None
    return tuple(int(p) for p in v.split("."))


def bump_kind(cur, new):
    """Classify a version change as major / minor-or-patch / not-an-upgrade."""
    c, n = semver(cur), semver(new)
    if c is None or n is None:
        return "unparseable"
    if n <= c:
        return "not-newer"
    # Pad so 1.2 vs 1.2.1 compares sanely.
    width = max(len(c), len(n))
    c = c + (0,) * (width - len(c))
    n = n + (0,) * (width - len(n))
    return "major" if n[0] != c[0] else "minor-or-patch"


def arg_name(tool):
    """betterleaks -> BETTERLEAKS_VERSION, osv-scanner -> OSV_SCANNER_VERSION."""
    return tool.upper().replace("-", "_") + "_VERSION"


def patch_lock(path, tool, cur, new):
    """Replace the version column for `tool`, preserving the column alignment.

    tools.lock is a fixed-column table read by humans, so the width taken by the
    version plus its trailing spaces is held constant. Every entry for the tool is
    updated: semgrep is listed twice (sast and skill-audit) and the drift check
    treats two different versions for one tool as a defect in its own right.
    """
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()
    pattern = re.compile(
        r"^(" + re.escape(tool) + r"[ \t]+)(" + re.escape(cur) + r")([ \t]+)",
        re.MULTILINE,
    )

    def repl(m):
        pad = len(m.group(3)) + (len(cur) - len(new))
        return m.group(1) + new + " " * max(pad, 1)

    out, n = pattern.subn(repl, text)
    if n:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(out)
    return n


def patch_dockerfiles(root, tool, cur, new):
    """Update `ARG <TOOL>_VERSION=<cur>` wherever it appears under toolbox/."""
    arg = arg_name(tool)
    pattern = re.compile(
        r"^(ARG[ \t]+" + re.escape(arg) + r"=)" + re.escape(cur) + r"$", re.MULTILINE
    )
    hits = []
    toolbox = os.path.join(root, "toolbox")
    for dirpath, _dirnames, filenames in os.walk(toolbox):
        for fn in filenames:
            if fn != "Dockerfile":
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding="utf-8", newline="") as f:
                text = f.read()
            out, n = pattern.subn(lambda m: m.group(1) + new, text)
            if n:
                with open(p, "w", encoding="utf-8", newline="") as f:
                    f.write(out)
                hits.append(os.path.relpath(p, root).replace(os.sep, "/"))
    return hits


def main():
    if len(sys.argv) != 3:
        print("usage: apply-tool-bumps.py <drift.tsv> <repo-root>", file=sys.stderr)
        return 1
    drift_file, root = sys.argv[1], sys.argv[2]
    lock = os.path.join(root, "toolbox", "tools.lock")

    if not os.path.exists(drift_file) or os.path.getsize(drift_file) == 0:
        print("No drift reported — nothing to bump.")
        return 0

    applied, skipped = [], []
    with open(drift_file, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            parts = raw.split("\t")
            if len(parts) != 3:
                skipped.append((raw, "malformed drift row"))
                continue
            tool, cur, new = parts
            kind = bump_kind(cur, new)
            if kind != "minor-or-patch":
                skipped.append(
                    (tool, "major version bump — needs a changelog read"
                     if kind == "major" else kind)
                )
                continue

            n_lock = patch_lock(lock, tool, cur, new)
            files = patch_dockerfiles(root, tool, cur, new)
            if not n_lock and not files:
                # The pin moved between the drift check and now, or the ARG does
                # not follow the naming rule. Either way: do not pretend it worked.
                skipped.append((tool, "pinned value not found in lock or Dockerfiles"))
                continue
            applied.append((tool, cur, new, n_lock, files))

    if applied:
        print("### Bumped\n")
        print("| Tool | From | To | Files |")
        print("|---|---|---|---|")
        for tool, cur, new, n_lock, files in applied:
            where = ", ".join(["toolbox/tools.lock x%d" % n_lock] + files)
            print("| %s | `%s` | `%s` | %s |" % (tool, cur, new, where))
        print("")
    if skipped:
        print("### Left alone\n")
        for tool, why in skipped:
            print("- `%s` — %s" % (tool, why))
        print("")
    if not applied:
        print("Nothing applied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
