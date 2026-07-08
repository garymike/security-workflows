# 3. Toolbox images as the single source of truth

## Status
Accepted

## Context
Secret scanning existed in two places — a marketplace `gitleaks-action` in the reusable
workflow AND a gitleaks binary in the image — with two version pins and drift risk.

## Decision
The signed toolbox images are the single source of truth. Reusable scanning workflows
invoke scanners *through the pinned image* (`docker run` / the `toolbox-scan` action);
only genuinely platform-native capabilities (CodeQL, dependency-review, the `gh api`
settings audit) remain native actions. Nothing is pinned twice.

## Alternatives considered
**Action-first with duplication** — lower per-run latency (no image pull), but
reintroduces double-pinning and version drift.

## Consequences
One pin point per tool (`tools.lock`); everything inherits the signed/verified supply
chain. Cost: consumers `docker pull` an image per run (a few seconds). **Revisit
trigger:** if that latency becomes a real cost for consumers, reconsider the
action-first path.
