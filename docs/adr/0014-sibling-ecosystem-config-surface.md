# ADR-0014: sibling-ecosystem config surface, and how an ecosystem earns a place in the gate

## Status
Accepted (2026-07-20).

## Context
ADR-0013 covered the config-injection surface for Claude Code specifically. The same class,
auto-run config that executes with no consent step on clone or open, is not unique to Claude Code.
The gate was already designed for this: the config-surface glob list is a single, clearly-labeled
extension point (see the comment in `skill-testfile-gate.sh`), so adding an ecosystem should cost a
glob and, where the ecosystem's own mechanism needs it, one rule file, not a new engine.

Not every editor's config file belongs here. A config file that merely exists is not a threat; the
bar is whether it genuinely auto-runs without the user taking an action that constitutes informed
consent. Three candidates were researched against that bar.

## Decision

**Viable, added:**
- **Cursor MCP** (`.cursor/mcp.json`): the same `mcpServers`/`command`/`args` shape as Claude Code's
  `.mcp.json`, so the existing generic malice rules and the `config-mcp-package-runner` warning apply
  with no new rule, only the new glob. CVE-2025-54136 ("MCPoison", patched in Cursor 1.3) showed
  Cursor's own approval was bound to the MCP server's name, not its command or arguments, so a
  config approved once could be silently mutated to something hostile without re-prompting. A static
  scan that reads content rather than trusting an editor's approval state is defense-in-depth for
  exactly that class of trust-model bug, the same argument already made for CVE-2025-59536.
- **Cursor Hooks** (`.cursor/hooks.json`): shell commands bound to lifecycle events
  (`beforeShellExecution`, `afterFileEdit`, and others), committed to the repo, loaded on project
  open. Structurally the same mechanism as Claude Code's Hooks. No dedicated CVE is cited for this
  file specifically; the case rests on the structural analogy, stated as such rather than implied.
- **VS Code tasks** (`.vscode/tasks.json`): a task with `runOptions.runOn: "folderOpen"` and
  `presentation.reveal: "silent"` runs with no visible output and no prompt the moment a folder is
  opened, a disclosed VS Code security issue (github.com/microsoft/vscode issue 309406), fixed
  upstream in 1.117.0. This needed one new rule (`sibling-vscode-silent-autorun`), because the
  dangerous signal is a specific combination of two JSON fields, not a content pattern the existing
  rules already read. A `runOn: "folderOpen"` task without the silent presentation setting is not
  flagged: that is the ordinary, common pattern of visibly running a setup step on open, and blocking
  it would be the same cry-wolf failure the `npx`-warns-not-blocks decision in ADR-0013 avoided.

**Not viable, excluded:** **direnv (`.envrc`)**. direnv already has its own consent gate: a new or
changed `.envrc` is not evaluated until the user runs `direnv allow`, and any subsequent content
change requires `direnv allow` again before it reloads. That closes the exact class this gate exists
for, including the rug-pull path (approve once, mutate later) that made Cursor's MCPoison exploitable.
Building a profile here would overstate the risk; direnv's own design is the mitigation, so the correct
response is to check, find it already handled, and not build.

## Consequences
Two new files added: `sibling-config-surface.yml` (the one rule specific to a sibling ecosystem's own
mechanism) and the fixture `sibling-config-demo` (one finding per new file, verified by tracing each
rule's regex against the fixture content before writing anything, matching the standard set for the
Claude Code config surface). `config-injection-benign` was extended, not duplicated, with the same
three files in their benign form, so the no-cry-wolf proof stays in one place.

This is a living list, not a closed one. The next candidate ecosystem is added by the same method:
confirm it genuinely auto-runs with no consent step, find or write the minimum rule needed, add a
malicious and a benign fixture, prove both in `gate-proof.sh`. An ecosystem that turns out to already
have its own working consent gate, the way direnv does, is a negative result worth recording, not a
gap worth building around.
