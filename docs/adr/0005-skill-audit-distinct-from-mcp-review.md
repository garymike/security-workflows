# 5. Skill-audit and MCP-review as distinct chunks

## Status
Accepted

## Context
A skill and an MCP server can overlap (a skill may bundle an MCP server), which tempts a
single merged "agent-artifact" scanner.

## Decision
Keep two distinct images/workflows. `mcp-review-toolbox` + the `mcp-security-review` skill
assess MCP servers; `skill-audit-toolbox` + `skill-audit.yml` assess Anthropic Skill
packages. They cross-reference but have genuinely different artifacts and threat models.

## Consequences
Each chunk stays focused and lean (consistent with [ADR-0002](0002-layered-signed-base.md)).
`snyk-agent-scan` lives in mcp-review; `SkillSpector` in skill-audit. A skill that bundles
an MCP server can be run through both.
