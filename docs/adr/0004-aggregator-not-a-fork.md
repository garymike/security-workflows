# 4. Aggregator & harness, not a fork

## Status
Accepted

## Context
It is tempting to fork/vendor security tools to customize them. That path means
maintaining someone else's functionality forever.

## Decision
This repo integrates established upstream tools as pinned artifacts (release
binaries, pip wheels, images) and tracks upstream for updates. It never re-implements or
maintains a tool's functionality. First-party code exists only for a documented gap with
no upstream answer, and carries a **sunset rule**: when upstream covers the gap, drop
ours and aggregate theirs.

## Consequences
`check-tool-updates.sh` plus the [tool-evaluation ledger](../tool-evaluations.md) keep
the aggregation deliberate. The only first-party logic is `skill-testfile-gate` (a
documented, unserved gap; see [ADR-0006](0006-skill-scanning-is-signal-not-verdict.md)),
which is slated to be upstreamed. Availability is hedged by optionally mirroring
artifacts, never by forking source.
