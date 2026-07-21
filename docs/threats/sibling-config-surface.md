# Threat: the config-injection class in sibling ecosystems

**Grounding:** CVE-2025-54136 ("MCPoison", Cursor, patched in 1.3); a disclosed VS Code security
issue (github.com/microsoft/vscode issue 309406, fixed in 1.117.0). See
[`../references.md`](../references.md).
**Surface:** developer-execution, the config-injection surface extended past Claude Code.
**Status:** Covered, enforced (Cursor MCP, Cursor Hooks, VS Code tasks). direnv's `.envrc` was
checked and found already mitigated; see below.

## The attack
[ADR-0013](../adr/0013-config-injection-surface.md) covered Claude Code's own auto-run config. The
same class shows up in other editors that clone-and-open a repo and read its committed config:

- **Cursor MCP** (`.cursor/mcp.json`): a server's `command`/`args` executes when the project opens.
  MCPoison showed Cursor's approval prompt is bound to the server's name, not its command, so a
  config approved once can be silently mutated to something hostile without a second prompt.
- **Cursor Hooks** (`.cursor/hooks.json`): shell commands bound to lifecycle events
  (`beforeShellExecution`, `afterFileEdit`), the same mechanism as Claude Code's Hooks.
- **VS Code tasks** (`.vscode/tasks.json`): a task with `runOn: "folderOpen"` and its terminal panel
  hidden (`reveal: "silent"`) runs with no visible output and no prompt the moment the folder opens.

## Why tooling misses it
Skill and agent scanners read `SKILL.md` and agent-invoked scripts. None of these three files are
either: they are read by the editor itself, not the agent, and they run on project open regardless of
whether any skill is involved.

## How this platform stops it
[`skill-testfile-gate`](../../toolbox/skill-audit/skill-testfile-gate.sh) inventories all three files.
Cursor's MCP and Hooks files are plain text, so the existing credential-read, curl-pipe-to-shell,
decode-and-exec, and reverse-shell rules already cover hostile content in them with no new rule, only
a new glob. VS Code's danger is a specific combination of two JSON fields rather than a content
pattern, so it gets one new rule
([`sibling-vscode-silent-autorun`](../../toolbox/skill-audit/rules/sibling-config-surface.yml)): a
`runOn: "folderOpen"` task without the silent presentation setting is not flagged, since that is the
ordinary, visible way to run a setup step on open.

## Proof
- Demo: [`sibling-config-demo`](../../tests/fixtures/sibling-config-demo), a malicious Cursor MCP
  command, a malicious Cursor hook, and a silent auto-run VS Code task, one distinct finding per file.
- Benign: [`config-injection-benign`](../../tests/fixtures/config-injection-benign), extended with the
  same three files in their ordinary, harmless form.
- Assertions: [`gate-proof.sh`](../../tests/gate-proof.sh) checks 8 and 9. Check 8 confirms the block
  and that all three files are individually named in the output, not just that something fired.
- Decision: [ADR-0014](../adr/0014-sibling-ecosystem-config-surface.md), which also records why
  direnv's `.envrc` was checked and excluded.

## Honest residual
direnv already has its own consent gate: `direnv allow` is required before a new or changed `.envrc`
runs, closing this exact class by design, including the rug-pull path (approve once, mutate later)
that made MCPoison exploitable. It is intentionally not covered here; building a profile for an
already-mitigated surface would overstate the risk. The three covered ecosystems, like the Claude Code
surface, are checked against their upstream-patched version; the gate is a pre-open scan and
defense-in-depth for the class, valuable on an unpatched or misconfigured editor regardless of any
single vendor fix.
