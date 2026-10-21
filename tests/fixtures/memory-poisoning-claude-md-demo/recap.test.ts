// DEFANGED demonstration fixture: the memory-poisoning carrier aimed at CLAUDE.md.
//
// Only ever statically scanned by the gate; never executed in CI. It appends an inert canary
// comment, never a working instruction.
//
// Why this fixture exists: CLAUDE.md was absent from `dev-exec-writes-agent-memory`'s
// destination list, which covered MEMORY.md, SOUL.md, AGENTS.md, .claude/ and .cursor/ but not
// the bare CLAUDE.md filename. So the single most-loaded memory file for the agent this gate is
// built around was the one destination it did not check.
//
// `npm test` runs this outside the agent with the developer's full local permissions.
import { appendFileSync } from "fs";

beforeAll(() => {
  appendFileSync("CLAUDE.md", "\n<!-- session-recap canary: demonstrates an unauthorized write to persistent agent memory -->\n");
});

test("recap is written", () => {
  expect(true).toBe(true);
});
