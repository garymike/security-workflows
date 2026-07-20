# Contributing

This is a small, security-focused platform; the bar is pinned, signed, and dogfooded.
A few conventions keep it that way.

## Local development

Build the layered images (base first, then any domain image `FROM` the local base):

```bash
docker build -t security-toolbox-base:ci ./toolbox/base
docker build --build-arg BASE=security-toolbox-base:ci -t gha-toolbox:ci ./toolbox/gha
# run a scanner
docker run --rm -v "$PWD:/src:ro" -w /src gha-toolbox:ci actionlint -color
```

`dogfood-scan.yml` runs this whole flow in CI on every PR. If it builds and passes
locally, it'll pass there.

## Adding or updating a scanner

This repo is an aggregator, not a fork
([ADR-0004](docs/adr/0004-aggregator-not-a-fork.md)): pin an upstream tool as an artifact;
never vendor its source. To add or bump one:

1. Update the tool's `ARG` in the relevant `toolbox/*/Dockerfile` and its line in
   [`toolbox/tools.lock`](toolbox/tools.lock).
2. Keep `scripts/check-tool-updates.sh` in sync; it reports version drift weekly.
3. Record the selection decision in [`docs/tool-evaluations.md`](docs/tool-evaluations.md).
4. First-party code is only for a documented gap with no upstream answer, and carries a
   sunset rule (see `skill-testfile-gate`).

## Change flow

`main` is protected ([ADR-0009](docs/adr/0009-solo-branch-protection.md)): every change
goes through a PR with a signed commit and must pass the CI gate before merge.

- **Sign your commits.** Configure SSH commit signing and register the key on GitHub as a
  *Signing Key*; `main` requires verified signatures.
- Branch, open a PR, get CI (`dogfood-scan`) green, then merge. No direct pushes to `main`.

## Releases

SemVer, mirroring the process documented for `garymike/skills`:

1. Roll `CHANGELOG.md` `[Unreleased]` to `[vX.Y.Z]` with a date.
2. Annotated, signed tag: `git tag -s vX.Y.Z -m vX.Y.Z`; move the major tag
   (`git tag -f vN vX.Y.Z`).
3. Push tags, then `gh release create vX.Y.Z --notes-file <that CHANGELOG section>`.

## Design docs

[`docs/architecture.md`](docs/architecture.md) · [`docs/adr/`](docs/adr/) ·
[`docs/threat-model.md`](docs/threat-model.md). Read these before proposing structural
changes.
