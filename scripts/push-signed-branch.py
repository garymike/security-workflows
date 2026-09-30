#!/usr/bin/env python3
"""Commit the working tree's changes to a branch as a GitHub-signed commit.

`main` requires signed commits. A commit made by `git commit` inside Actions is
signed by nobody -- GITHUB_TOKEN is not a signing key -- so the branch this job
used to push could never be merged without an admin bypass. That is not a stuck
PR to be forced through once; it is every week, forever, and it trains whoever
is on the other end to reach for --admin as routine.

GitHub's GraphQL `createCommitOnBranch` mutation signs server-side with its own
key, so a commit made through it is `Verified` and merges under the rule like any
other. Same token, same permission (`contents: write`), no bot signing key to
store or rotate.

The branch is reset to the commit this run was built from before committing, so
consecutive weeks refresh one long-lived branch instead of leaving a trail of
stale ones -- the behaviour the old `git push --force` had.

This asserts the resulting commit is actually verified and fails if it is not.
Silently producing an unmergeable branch is the exact failure being fixed, and it
is invisible until someone tries to merge weeks later.

Usage: push-signed-branch.py <repo> <branch> <base-sha> <headline> [body-file]
Exit:  0 = committed, 1 = error (nothing to commit is an error; the caller
       decides whether the tree is dirty before calling).
"""
import base64
import json
import os
import subprocess
import sys


def run(*args, **kw):
    """Run a command, returning stdout. Raises on non-zero."""
    return subprocess.run(
        args, capture_output=True, text=True, check=True, **kw
    ).stdout


def gh_api(*args, stdin=None):
    """Call `gh api`, returning parsed JSON. Uses GH_TOKEN from the environment."""
    p = subprocess.run(
        ("gh", "api") + args, capture_output=True, text=True, input=stdin
    )
    if p.returncode != 0:
        raise RuntimeError(f"gh api {' '.join(args)} failed: {p.stderr.strip()}")
    return json.loads(p.stdout) if p.stdout.strip() else {}


MUTATION = """
mutation($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) {
    commit { oid url signature { isValid state } }
  }
}
"""


def main(argv):
    if not 5 <= len(argv) <= 6:
        sys.exit(__doc__)
    repo, branch, base_sha, headline = argv[1:5]
    body = ""
    if len(argv) == 6:
        with open(argv[5], encoding="utf-8") as fh:
            body = fh.read()

    # Modified and added files go in `additions`, removed ones in `deletions`.
    # A tool bump only ever rewrites files in place, but a Dockerfile being
    # dropped from the set would otherwise be committed as "no change" and the
    # branch would quietly disagree with the tree that was validated.
    changed = run("git", "diff", "--name-only", "--diff-filter=d").split()
    deleted = run("git", "diff", "--name-only", "--diff-filter=D").split()
    if not changed and not deleted:
        print("nothing to commit -- working tree is clean", file=sys.stderr)
        return 1

    additions = []
    for path in changed:
        with open(path, "rb") as fh:
            additions.append(
                {"path": path, "contents": base64.b64encode(fh.read()).decode()}
            )

    # Reset the long-lived branch to this run's base commit. Create it if the
    # branch does not exist yet (first run, or after someone deleted it on merge).
    try:
        gh_api(f"repos/{repo}/git/refs/heads/{branch}")
    except RuntimeError:
        gh_api(
            f"repos/{repo}/git/refs", "-X", "POST",
            "-f", f"ref=refs/heads/{branch}", "-f", f"sha={base_sha}",
        )
    else:
        gh_api(
            f"repos/{repo}/git/refs/heads/{branch}", "-X", "PATCH",
            "-f", f"sha={base_sha}", "-F", "force=true",
        )

    payload = {
        "query": MUTATION,
        "variables": {
            "input": {
                "branch": {
                    "repositoryNameWithOwner": repo,
                    "branchName": branch,
                },
                "expectedHeadOid": base_sha,
                "message": {"headline": headline, "body": body},
                "fileChanges": {
                    "additions": additions,
                    "deletions": [{"path": p} for p in deleted],
                },
            }
        },
    }

    result = gh_api("graphql", "--input", "-", stdin=json.dumps(payload))
    if "errors" in result:
        print(json.dumps(result["errors"], indent=2), file=sys.stderr)
        return 1

    commit = result["data"]["createCommitOnBranch"]["commit"]
    sig = commit.get("signature") or {}
    state = sig.get("state")
    print(f"committed {commit['oid'][:12]} to {branch} ({len(additions)} files)")
    print(commit["url"])

    # The whole point. An unsigned commit here cannot merge into a branch that
    # requires signatures, so fail now rather than at merge time.
    if state != "VALID" or not sig.get("isValid"):
        print(
            f"::error::commit {commit['oid'][:12]} is not verified "
            f"(signature state: {state or 'none'}). It cannot merge into a "
            f"branch requiring signed commits.",
            file=sys.stderr,
        )
        return 1
    print("signature: VALID")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
