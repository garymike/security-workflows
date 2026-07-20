# 7. STRIDE-in-CI deferred

## Status
Deferred

## Context
STRIDE threat-modeling tools (e.g. `mcp-stride-gpt`) are interactive LLM assistants that
hand a framework to a model to reason with, not deterministic static scanners.

## Decision
Keep this repo deterministic and static. STRIDE modeling belongs on the skills side
(`garymike/skills`; `secure-mcp-builder` already ships a threat-model template), not as a
scanner or image here.

## Consequences
No LLM-in-CI non-determinism in the platform. **Revisit trigger:** if an LLM-in-CI
design-review gate becomes desirable, reconsider it as a thin workflow that invokes the
skill/MCP, never a scanner baked into an image.
