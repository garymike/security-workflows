# 2. Layered signed base + domain toolboxes

## Status
Accepted

## Context
The original single `mcp-review-toolbox` image mixed generic scanners (secrets, deps,
SBOM) with MCP-specific ones. Adding GitHub-Actions-security and skill-audit tooling to
one image would bloat it and blur its purpose.

## Decision
Publish a signed `security-toolbox-base` with the generic scanner spine; each domain
image (`mcp-review-toolbox`, `gha-toolbox`, `skill-audit-toolbox`) builds
`FROM base@digest`, adding only what is domain-specific. Split a domain image out the
moment it needs a tool the others don't ("split-on-first-divergent-tool").

## Consequences
A shared, hardened base layer; lean domain images; adding a new domain image is a
one-line matrix entry in `build-toolbox.yml`. A base bump triggers child rebuilds via
CI `needs`. Each image is independently SBOM'd, provenance-attested, and cosign-signed.
