#!/usr/bin/env python3
"""Do the reusable workflows pin images built from the CURRENT repo inputs?

The five reusable workflows pin their toolbox image by digest, deliberately (#73): a rebuild must
not silently change what every caller scans with, after betterleaks 1.6.1 -> 1.8.1 in #64 turned
green repos red overnight. The cost of "deliberate" is that nothing moves the pin for you, so a
tool bump can publish a new image while every caller keeps scanning with the previous toolchain.

#88 checked that by comparing each pin against the digest the build had just published. That was
wrong, and measurably so: it failed on 4 of 4 runs after it landed, including the 2026-10-26
SCHEDULED rebuild, where nothing in the repo had changed and all six image jobs passed. The
premise was that a rebuild with unchanged inputs yields a byte-identical digest. It does not. The
Dockerfiles run `apt-get update && apt-get install`, so a rebuild days later pulls different
packages and publishes a different digest. The check could never stay green longer than it took
the next rebuild to run, and "pins behind" stopped carrying information.

So this asks a question whose answer only changes when a human changes something: does the pinned
image carry a stamp of the same build INPUTS this repo has now? build-toolbox.yml stamps every
image it publishes with `git ls-files -s` over that image's inputs, which is stable across
rebuilds and moves when a tracked file moves. Reading it back costs four small registry calls per
image and pulls no layers.

A pinned image carrying no stamp predates this check and is reported UNVERIFIABLE, not passing: a
check that reports success on absent input is the failure mode this replaces.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

LABEL = "io.github.garymike.toolbox.build-inputs"

ACCEPT = ",".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])

# workflow -> (image name, that image's own build context under toolbox/)
# Every domain image is built FROM the base by digest, so toolbox/base is an input to all of them.
# mcp-review-toolbox is built but no reusable workflow pins it, so it is not listed.
PINNED = {
    "security-scan.yml": ("security-toolbox-base", "toolbox/base"),
    "gha-security.yml":  ("gha-toolbox",           "toolbox/gha"),
    "sast.yml":          ("sast-toolbox",          "toolbox/sast"),
    "iac-security.yml":  ("iac-toolbox",           "toolbox/iac"),
    "skill-audit.yml":   ("skill-audit-toolbox",   "toolbox/skill-audit"),
}


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def stamp(context):
    """Fingerprint this image's tracked build inputs. Must match build-toolbox.yml exactly."""
    paths = ["toolbox/base", "toolbox/tools.lock"]
    if context != "toolbox/base":
        paths.insert(1, context)
    return hashlib.sha256(sh("git", "ls-files", "-s", "--", *paths).encode()).hexdigest()


def get(url, token=None, accept=None):
    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if accept:
        req.add_header("Accept", accept)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def pinned_stamp(repo_path, digest):
    """index -> the one real platform manifest -> its config blob -> our label. No layer pulls."""
    scope = "repository:{}:pull".format(repo_path)
    token = get("https://ghcr.io/token?scope={}&service=ghcr.io".format(scope))["token"]
    top = get("https://ghcr.io/v2/{}/manifests/{}".format(repo_path, digest), token, ACCEPT)
    if "manifests" in top:
        # `sbom: true` + `provenance: mode=max` means the pinned ref is an OCI index carrying an
        # attestation manifest alongside the image. The attestation one reports platform
        # unknown/unknown. Picking the wrong member here is how two of five pins went in wrong
        # in #82, so require exactly one real platform rather than taking the first entry.
        real = [m for m in top["manifests"]
                if (m.get("platform") or {}).get("os") not in (None, "unknown")]
        if len(real) != 1:
            raise RuntimeError("expected one platform manifest, found {}".format(len(real)))
        top = get("https://ghcr.io/v2/{}/manifests/{}".format(repo_path, real[0]["digest"]),
                  token, ACCEPT)
    config = get("https://ghcr.io/v2/{}/blobs/{}".format(repo_path, top["config"]["digest"]), token)
    return ((config.get("config") or {}).get("Labels") or {}).get(LABEL)


def main():
    owner = os.environ.get("GITHUB_REPOSITORY", "garymike/security-workflows").lower()
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    rows = []
    bad = 0

    for workflow, (image, context) in sorted(PINNED.items()):
        path = os.path.join(".github", "workflows", workflow)
        want = stamp(context)

        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except OSError as exc:
            print("::error::cannot read {}: {}".format(path, exc))
            bad += 1
            continue

        found = re.search(re.escape(image) + r"@(sha256:[0-9a-f]{64})", text)
        if not found:
            print("::error::{} has no {} digest pin to check".format(workflow, image))
            rows.append((image, workflow, want[:12], "-", "NO PIN"))
            bad += 1
            continue
        digest = found.group(1)

        try:
            got = pinned_stamp("{}/{}".format(owner, image), digest)
        except (urllib.error.URLError, RuntimeError, KeyError, ValueError) as exc:
            print("::error::{}: cannot read the pinned image {}@{}: {}".format(
                workflow, image, digest[7:19], exc))
            rows.append((image, workflow, want[:12], "unreadable", "ERROR"))
            bad += 1
            continue

        if got is None:
            print("::error::{} pins {}@{}, which carries no {} label. It was built before this "
                  "check existed, so what it holds cannot be verified from the registry. Move the "
                  "pin to a digest published by a build that stamps it.".format(
                      workflow, image, digest[7:19], LABEL))
            rows.append((image, workflow, want[:12], "none", "UNVERIFIABLE"))
            bad += 1
        elif got != want:
            print("::error::{} pins {}@{}, built from inputs {}, but this repo's inputs for it are "
                  "now {}. A tracked file under {}, toolbox/base or toolbox/tools.lock has changed "
                  "since that image was built, so callers are scanning with the previous build. "
                  "Move the pin to the digest the latest build published.".format(
                      workflow, image, digest[7:19], got[:12], want[:12], context))
            rows.append((image, workflow, want[:12], got[:12], "BEHIND"))
            bad += 1
        else:
            print("  {}: {} pin is current (inputs {})".format(workflow, image, want[:12]))
            rows.append((image, workflow, want[:12], got[:12], "current"))

    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write("| image | workflow | repo inputs now | pinned image built from | |\n")
            fh.write("|---|---|---|---|---|\n")
            for row in rows:
                fh.write("| `{}` | `{}` | `{}` | `{}` | {} |\n".format(*row))
            if bad:
                fh.write(
                    "\n### Pins are behind\n\n"
                    "The images themselves are fine. What is missing is the second half of a tool "
                    "or toolbox change: move the digest pins in the reusable workflows to what the "
                    "latest build published, in their own commit. The digest does not exist until "
                    "the publish has happened, which is why this is always a follow-up rather than "
                    "part of the bump.\n")

    if not rows:
        print("::error::no pins were checked at all, so this run proves nothing")
        return 1
    if bad:
        print("\n{} of {} pins are not current.".format(bad, len(rows)))
        return 1
    print("\nAll {} reusable-workflow image pins were built from the current repo inputs.".format(
        len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
