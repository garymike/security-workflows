# 1. Repo boundary & name

## Status
Accepted

## Context
The repo is evolving from a couple of reusable workflows into a multi-image security
platform. A separate `garymike/skills` repo hosts authored agent skills
(`mcp-security-review`, `secure-mcp-builder`). Where is the line, and does the name
still fit?

## Decision
`security-workflows` keeps its name and is the **scanning / CI / toolbox platform**. It
*scans* skills and MCP servers; it does not *host* authored skills — those stay in
`garymike/skills` and point at these toolboxes as an optional fast path. Renaming a
public repo would break every `uses:` reference and the GHCR image paths for marginal
gain; reposition in the README instead.

## Consequences
Clean separation of concerns: skills = methodology/judgment; this repo = pinned
execution + CI gates. The skill-audit capability here is about consuming/scanning
skills-as-artifacts, not authoring them.
