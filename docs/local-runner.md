# Local runner: run the gate anywhere, no Docker Desktop required

The developer-execution vector is most lethal locally, before push: a malicious skill
detonates the moment you run the project's tests. So the gate should run on the workstation, not
just in CI. It runs off the same signed `skill-audit-toolbox` image as CI (same `tools.lock`,
one cryptographic source of truth), via whatever OCI runtime you have: Docker, Podman, or
Windows WSL Containers (`wslc`).

## The wrapper: `bin/skill-gate`

[`bin/skill-gate`](../bin/skill-gate) detects the first functional runtime (`docker`, then `podman`,
then `wslc`) and runs the gate against a path:

```bash
./bin/skill-gate .                 # scan the current repo
./bin/skill-gate path/to/skill     # scan a specific skill/dir
SKILL_GATE_RUNTIME=wslc ./bin/skill-gate .   # force a runtime
```

It health-checks each candidate (installed ≠ running, e.g. Podman with no machine, or Docker
Desktop not started), and on Windows/git-bash it translates paths for the Windows runtime
automatically. Exit `1` = a malicious pattern on the developer-execution surface (block).

## As a pre-commit hook

Two hooks ship in [`.pre-commit-hooks.yaml`](../.pre-commit-hooks.yaml):

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/garymike/security-workflows
    rev: v1.2.0
    hooks:
      - id: skill-testfile-gate       # Docker-native (simplest if you have Docker)
      # - id: skill-testfile-gate-any # runtime-agnostic: docker / podman / wslc (no Docker Desktop)
```

Install on the stages that matter: at commit, and when a skill arrives via a pull, before `npm test`:

```bash
pre-commit install --hook-type pre-commit --hook-type post-merge --hook-type post-checkout
```

## WSL Containers (`wslc`): no Docker Desktop

`wslc` is a Linux container runtime built into WSL. Many enterprises block Docker Desktop
(licensing) but allow WSL, so `wslc` is the path to a local gate for that population.

**Install** (public preview ships in the WSL pre-release channel):

```powershell
wsl --update --pre-release      # brings in wslc (>= 2.9.3); revert with a plain `wsl --update`
```

This is verified working. It pulls from GHCR, bind-mounts a Windows path, and runs the gate:

```powershell
wslc run --rm -v "C:\path\to\skill:/src:ro" `
  ghcr.io/garymike/security-workflows/skill-audit-toolbox:latest `
  skill-testfile-gate /src
```

> Verified 2026-07-09 on Windows 11 25H2 (build 26200.8737), WSL 2.9.3, wslc 2.9.3.0, with no
> Docker installed: `wslc run` pulled the signed image from `ghcr.io`, the Docker-style `-v`
> bind mount worked with a Windows drive-letter path, and the gate blocked the demo fixture
> (`malice: 1`, exit 1), byte-identical to the Docker and CI runs. `bin/skill-gate` auto-selected
> `wslc` on the same box and produced the same result.

Preview status. WSLC is a public preview (GA planned for fall 2026). The local
gate is verified manually on the environment above, but it is not exercised in CI (GitHub's
runners don't ship `wslc`), so the continuously-enforced guarantees remain the Docker path (the
[proof-fixture](../tests/gate-proof.sh) runs on Docker). `docker compose` is not yet supported by
`wslc`, so the compose-based `security-agents` agent flavors stay on Docker for now; this local
track is the single-container gate only.

## Offline / air-gapped

The signed image runs offline once present. Sideload it without a registry pull:

```powershell
# On a connected machine: save the image to a tarball
wslc save ghcr.io/garymike/security-workflows/skill-audit-toolbox:latest -o skill-audit-toolbox.tar
# On the air-gapped machine: import and run (no network)
wslc import skill-audit-toolbox.tar
wslc run --rm -v "C:\src:/src:ro" skill-audit-toolbox:latest skill-testfile-gate /src
```

Verify the tarball's provenance first (`cosign verify` against the published signature) so the
air-gapped copy inherits the same trust as the online one.

## Performance

WSLC's default `virtiofs` file driver makes file access between Windows and Linux about 2× faster, worth noting
for scanning large trees, where the gate walks the whole directory.

## Enterprise management

WSLC is manageable where Docker Desktop often isn't:

- **Group Policy (ADMX):** control who can use containers, and an allowlist of registries that
  images may be pulled from. An org can allowlist `ghcr.io/garymike/*` and mandate the local gate.
- **Intune** dashboards (rolling out) and a **Microsoft Defender** plugin aware of Linux container
  events.

## Beyond containers (future)

**QEMU** is a deliberate future option, not built here:

- **Mac/Linux parity:** if a non-container-runtime path is ever needed on those platforms.
- **Stronger isolation:** a VM boundary (vs. a container) for the Tier-2 dynamic sandbox that
  executes untrusted skills ([security-agents](https://github.com/garymike/security-agents)).
  That's an isolation concern for the dynamic tier, not this static local gate.

Deferred until there's real pull for it; the container path (Docker/Podman/WSLC) covers the gate today.
