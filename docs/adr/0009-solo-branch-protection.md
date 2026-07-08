# 9. Solo-maintainer branch protection

## Status
Accepted

## Context
`main` required a PR + signed commits + an approving review. Solo, you cannot approve
your own PR — which forced an admin "bypass rules" on every merge.

## Decision
`main` requires a PR + signed commits + passing CI (the dogfood check), with
**required approvals = 0** (self-approval is impossible solo). The admin bypass is
retained as an escape hatch. Commits are signed with a dedicated SSH signing key.

## Consequences
The solo flow is branch → PR → signed commit → CI → self-merge, with zero routine
bypass. **Revisit trigger:** raise required approvals to 1 the moment a collaborator
joins.
