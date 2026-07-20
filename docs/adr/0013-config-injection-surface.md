# ADR-0013: config-injection is the developer-execution boundary extended to agent config

## Status
Accepted (2026-07-19).

## Context
ADR-0011 drew the developer-execution surface as files a skill bundles that the developer's toolchain
auto-runs outside the agent. Check Point's CVE-2025-59536 (CVSS 8.7) showed the same class in the
agent's own config: a repo's `.claude/settings.json` Hooks and `.mcp.json` MCP definitions auto-execute
shell on clone or open of an untrusted project, with no consent prompt. CVE-2026-21852 (5.3) is the
token-theft variant. Both are patched upstream.

## Decision
Extend `skill-testfile-gate` to inventory the config surface (`.claude/settings.json`,
`.claude/settings.local.json`, `.mcp.json`, `.claude.json`, `.claude/hooks/*`) and scan it with the
existing malice rules plus two config-specific rules:

- ERROR (block): an `env` block that injects a code-execution variable (LD_PRELOAD, NODE_OPTIONS with
  `--require`, BASH_ENV, PYTHONSTARTUP, PERL5OPT, GIT_SSH_COMMAND, PROMPT_COMMAND).
- WARNING (escalate): an MCP server command that is a package runner (npx, uvx, and similar). This is
  the standard way to launch MCP servers, so blocking it would cry wolf; it is flagged for review.

Presence of config is inventory (low, non-blocking), consistent with ADR-0012. A hostile command
blocks; a package-runner launch warns. The gate loads the rules directory, so each surface keeps its
own rule file.

## Consequences
The CVEs are patched upstream, so this is defense-in-depth for the class: a pre-open scan of
auto-executing repo config, valuable regardless of any single vendor patch. It broadens the gate's
differentiator from a skill's bundled test file to any auto-run repo file, including the agent's own
config. The config-surface glob list and the per-surface rule file are the extension points for
sibling ecosystems (`.cursor`, `.vscode`, `.envrc`) if a future viability check justifies them.
