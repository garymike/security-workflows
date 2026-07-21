# Architecture Decision Records

The decisions behind `security-workflows`, in the order they were made.
Format: [Michael Nygard's ADRs](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html).
Research and incident sources cited in these ADRs have full citations in [`../references.md`](../references.md).

| # | Decision | Status |
|---|---|---|
| [0001](0001-repo-boundary-and-name.md) | Repo boundary & name | Accepted |
| [0002](0002-layered-signed-base.md) | Layered signed base + domain toolboxes | Accepted |
| [0003](0003-toolbox-single-source-of-truth.md) | Toolbox images as the single source of truth | Accepted |
| [0004](0004-aggregator-not-a-fork.md) | Aggregator & harness, not a fork | Accepted |
| [0005](0005-skill-audit-distinct-from-mcp-review.md) | Skill-audit and MCP-review as distinct chunks | Accepted |
| [0006](0006-skill-scanning-is-signal-not-verdict.md) | Skill scanning is a signal, not a verdict | Accepted |
| [0007](0007-stride-in-ci-deferred.md) | STRIDE-in-CI deferred | Deferred |
| [0008](0008-versioning.md) | Versioning: semver + moving major + SHA | Accepted |
| [0009](0009-solo-branch-protection.md) | Solo-maintainer branch protection | Accepted |
| [0010](0010-first-party-dev-exec-rule-pack.md) | First-party rule pack for the developer-execution surface | Accepted |
| [0011](0011-developer-execution-surface-boundary.md) | The developer-execution surface boundary | Accepted |
| [0012](0012-layered-severity-and-sarif.md) | Layered presence/malice severity + SARIF | Accepted |
| [0013](0013-config-injection-surface.md) | Config-injection: developer-execution boundary extended to agent config | Accepted |
| [0014](0014-sibling-ecosystem-config-surface.md) | Sibling-ecosystem config surface: which ecosystems earn a place, and why direnv does not | Accepted |
