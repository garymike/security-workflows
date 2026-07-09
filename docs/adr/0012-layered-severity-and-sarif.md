# 12. Layered presence/malice severity, and SARIF output

## Status
Accepted

## Context
A single verdict conflates two very different signals: an auto-executed file is *present*, versus
that file *does something hostile*. Blocking on presence false-positives every legitimate test
suite; ignoring presence throws away the pin-and-review inventory. And a naive "flag if any rule
fires" combiner over-triggers: MalSkillBench (arXiv 2606.07131) shows OR-combining a code-layer and
an instruction-layer detector yields up to **3,979 false positives on 4,000 benign** skills.

## Decision
Two layers, tiered by severity:

- **Inventory (low, WARNING)** — an auto-executed skill file is present. Reported, non-blocking by
  default (`GATE_FAIL_ON_INVENTORY=true` opts in). This is the pin-and-review signal.
- **Malice (high)** — Semgrep `ERROR` findings (plus an invisible/bidirectional-Unicode check)
  **block**; Semgrep `WARNING` findings are reported and flagged to **escalate to a sandbox run**.
  Never a naive OR of raw hits — severity is assigned per pattern.

Emit the malice layer as **SARIF** to GitHub code scanning (category `skill-testfile-gate`),
aligning the gate with `sast` / `iac` / `codeql`.

## Consequences
Legitimate bundled tests are no longer blocked — proven continuously by the CI proof-fixture
(`tests/gate-proof.sh`): the benign-skill fixture must stay unblocked, the gecko-demo must block.
Findings dedupe and severity-sort in code scanning. The escalate-to-sandbox path (the Tier-2
`security-agents` `skill-auditor`) is where an evadable static verdict is confirmed dynamically —
consistent with arXiv 2607.02357 (static = cheap pre-filter, dynamic execution auditing =
load-bearing defense) and [ADR-0006](0006-skill-scanning-is-signal-not-verdict.md).
