#!/usr/bin/env python3
"""Move the five reusable-workflow image pins to the digests a given commit's build published.

The follow-up half of any toolbox change: the digest to pin does not exist until the publish has
happened, so moving a pin is always a separate commit from the change that caused it.

Refuses to run when check-image-pins.py is green, because the two scripts answer DIFFERENT
questions and routinely disagree:

    check-image-pins.py   was the pinned image built from the current inputs?
    this script           does the pin name one specific build?

A rebuild publishes a new digest every time, since the Dockerfiles apt-get install current
packages, so "the pin names the newest build" goes false within a week of every pin move while
"built from current inputs" stays true. Running this routinely would therefore churn all five
pins to a functionally identical build, which is noise in a file whose whole point is that it
only changes deliberately.

--force exists for the one case the check is blind to on purpose. The weekly rebuild picks up
BASE-IMAGE patches, which change what callers run without changing any input this repo tracks,
so the check stays green while the pinned image ages. Pulling those patches through to callers
is a real reason to move a pin, and it has to be stated rather than inferred.

Self-verifying either way. For each image it reads the resolved digest's build-inputs label back
out of the registry and writes nothing unless every one of the five matches the fingerprint this
repo computes now.

Resolves the per-commit `sha-<commit12>` tag, never `latest`. Measured reason: before the
concurrency guard landed, two builds 25 seconds apart both pushed `latest` and for iac-toolbox
the EARLIER run's push landed last, so `latest` named the older build. The guard makes that
unlikely rather than impossible, and the per-commit tag cannot race at all.

Usage:
    move-image-pins.py <commit-ish> [--apply] [--force]

Exit: 0 = nothing to do, or applied. 1 = refused, or something did not verify.
"""

import importlib.util
import io
import os
import re
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)


def load_checker():
    """Reuse the checker's registry chain, so the two cannot disagree about resolution."""
    path = os.path.join(HERE, "check-image-pins.py")
    spec = importlib.util.spec_from_file_location("check_image_pins", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def tag_digest(pins, repo_path, tag):
    """Resolve a tag to the digest a pin should name (the index digest the build reported)."""
    scope = "repository:{}:pull".format(repo_path)
    token = pins.get("https://ghcr.io/token?scope={}&service=ghcr.io".format(scope))["token"]
    request = urllib.request.Request(
        "https://ghcr.io/v2/{}/manifests/{}".format(repo_path, tag), method="HEAD")
    request.add_header("Authorization", "Bearer " + token)
    request.add_header("Accept", pins.ACCEPT)
    with urllib.request.urlopen(request, timeout=30) as response:
        digest = response.headers["Docker-Content-Digest"]
    if not digest:
        raise RuntimeError("no Docker-Content-Digest header for " + tag)
    return digest


def pinned_digest(path, image):
    with io.open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    found = re.search(re.escape(image) + r"@(sha256:[0-9a-f]{64})", text)
    return (text, found.group(1) if found else None)


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__.strip().split("Usage:")[-1].strip())
        return 1
    apply_changes = "--apply" in argv
    force = "--force" in argv

    os.chdir(REPO_ROOT)
    pins = load_checker()
    owner = os.environ.get("GITHUB_REPOSITORY", "garymike/security-workflows").lower()

    commit = subprocess.run(["git", "rev-parse", args[0]],
                            capture_output=True, text=True, check=True).stdout.strip()
    tag = "sha-" + commit[:12]

    # --- is anything actually behind? ---------------------------------------
    behind = []
    for workflow, (image, context) in sorted(pins.PINNED.items()):
        path = os.path.join(".github", "workflows", workflow)
        want = pins.stamp(context)
        _, old = pinned_digest(path, image)
        if old is None:
            behind.append(workflow + " (no pin)")
            continue
        try:
            got = pins.pinned_stamp("{}/{}".format(owner, image), old)
        except Exception as exc:                        # noqa: BLE001 - report, never write
            behind.append("{} (unreadable: {})".format(workflow, exc))
            continue
        if got != want:
            behind.append(workflow)

    if not behind and not force:
        print("All five pins already name an image built from the current inputs, so there is")
        print("nothing for this script to correct. Refusing, because moving them anyway would")
        print("repoint every caller at a functionally identical build.")
        print("")
        print("If you mean to pull BASE-IMAGE patches through to callers, which the check cannot")
        print("see because they change no input this repo tracks, say so:")
        print("")
        print("    scripts/move-image-pins.py %s --force --apply" % args[0])
        return 1

    if behind:
        print("behind: %s" % ", ".join(behind))
    else:
        print("nothing is behind; proceeding because --force was given")
    print("pinning to the build of %s (tag %s)\n" % (commit[:12], tag))

    # --- resolve and verify before writing anything -------------------------
    rows = []
    edits = {}
    verified = True

    for workflow, (image, context) in sorted(pins.PINNED.items()):
        path = os.path.join(".github", "workflows", workflow)
        want = pins.stamp(context)
        text, old = pinned_digest(path, image)

        try:
            new = tag_digest(pins, "{}/{}".format(owner, image), tag)
            got = pins.pinned_stamp("{}/{}".format(owner, image), new)
        except Exception as exc:                        # noqa: BLE001 - report, never write
            rows.append((image, (old or "-")[7:19], "-", "UNRESOLVED: {}".format(exc)))
            verified = False
            continue

        if got is None:
            state = "that build carries NO STAMP"
            verified = False
        elif got != want:
            state = "stamp {} != repo {}".format(got[:12], want[:12])
            verified = False
        elif old is None:
            state = "NO EXISTING PIN TO REPLACE"
            verified = False
        elif old == new:
            state = "already names that build"
        else:
            state = "will move"
            edits[path] = (text, old, new)
        rows.append((image, (old or "-")[7:19], new[7:19], state))

    print("%-22s %-13s %-13s %s" % ("IMAGE", "PINNED NOW", "THAT BUILD", "STATE"))
    for row in rows:
        print("%-22s %-13s %-13s %s" % row)

    if not verified:
        print("\nnothing written: at least one image did not verify")
        return 1
    if not edits:
        print("\nevery pin already names that build; nothing to write")
        return 0
    if not apply_changes:
        print("\n%d file(s) would change. Re-run with --apply." % len(edits))
        return 0

    for path, (text, old, new) in sorted(edits.items()):
        count = text.count(old)
        with io.open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write(text.replace(old, new))
        print("wrote %s (%d occurrence(s))" % (path, count))
    print("\n%d file(s) updated. Run scripts/check-image-pins.py to confirm." % len(edits))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
