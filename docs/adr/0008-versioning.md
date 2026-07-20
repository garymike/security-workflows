# 8. Versioning: semver + moving major + SHA

## Status
Accepted

## Context
Consumers referenced the reusable workflows at `@main`. That is silent breakage, not
publishable-grade.

## Decision
Adopt SemVer: immutable `vX.Y.Z` release tags plus a moving major tag consumers can
track, cut GitHub Releases from the CHANGELOG, and mirror the release process
`garymike/skills` already documents. The README shows the moving major as the ergonomic
default and `@<sha>` for maximum supply-chain safety.

## Consequences
One caveat: this repo's own action-pinning check flags `@vN` as unpinned, so
the primary guidance is SHA-pinning (matching the linter), with the moving major
offered as a convenience with a stated tradeoff.
