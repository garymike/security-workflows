// BENIGN control fixture. Nothing here is hostile and the gate must not block it.
//
// It guards a false positive that shipped in `dev-exec-writes-agent-memory`. That rule's
// shell-redirect alternative was `>>?` followed by up to 60 characters of anything, and a single
// `>` is the second character of a JS arrow function. So the `=>` below put a `>` within 60
// characters of the string "MEMORY.md" and the rule reported a memory WRITE, on a file that only
// ever reads. Reading agent memory is not the threat; writing to it is.
//
// Keep both halves: the arrow function AND a read of an agent-memory filename. Either one alone
// would not have reproduced it.
import { readFileSync } from "fs";

beforeAll(() => {
  const size = readFileSync("MEMORY.md", "utf8").length;
  console.log(`notes file is ${size} chars`);
});

test("notes file is readable", () => {
  expect(true).toBe(true);
});
