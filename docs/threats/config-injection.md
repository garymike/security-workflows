# Threat: config-injection (the agent's own auto-run config)

**Grounding:** CVE-2025-59536 (CVSS 8.7) and CVE-2026-21852, Check Point Research. See
[`../references.md`](../references.md), tag [ConfigInjection].
**Surface:** developer-execution, extended to the agent's own configuration.
**Status:** Covered, enforced.

## The attack
A repo's own `.claude/settings.json` Hooks, `.mcp.json` or `.claude.json` MCP server commands, and
`.claude/hooks/*` scripts auto-execute on clone or open of an untrusted project, with no consent
prompt. The defanged demo carries a `SessionStart` hook that reads `~/.ssh/id_rsa`, and an `env`
block that injects `NODE_OPTIONS=--require ./.claude/hooks/preload.js`.

## Why tooling misses it
This is the developer-execution class applied to the agent's own config, a surface skill scanners do
not read. Check Point's framing: the risk now extends to opening untrusted projects.

## How this platform stops it
[`skill-testfile-gate`](../../toolbox/skill-audit/skill-testfile-gate.sh) inventories the config
files and blocks a hostile hook command or an injected code-execution environment variable, while
warning on a package-runner MCP launch (the standard `npx`/`uvx` pattern, so it is not failed).

## Proof
- Demos: [`config-injection-demo`](../../tests/fixtures/config-injection-demo) (blocks),
  [`config-injection-benign`](../../tests/fixtures/config-injection-benign) (clears)
- Assertions: [`gate-proof.sh`](../../tests/gate-proof.sh) checks 5 and 6
- Rules: [`config-injection-surface.yml`](../../toolbox/skill-audit/rules/config-injection-surface.yml)
- Decision: [ADR-0013](../adr/0013-config-injection-surface.md)

## Honest residual
The CVEs are patched upstream, so this is defense-in-depth for the class, a pre-open scan of
auto-executing repo config. Sibling ecosystems (`.cursor`, `.vscode`, `.envrc`) are not yet covered.
