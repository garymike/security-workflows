// BENIGN control fixture, the JS half of the near-miss case. The gate must not block it.
//
// MY_AGENTS.md is this team's own roster file. It ends in AGENTS.md, which is on the
// agent-memory destination list, but it is a different file: no agent loads it, and the match was
// only ever a substring accident. Keep the underscore prefix, because that is what makes the
// basename fail to start the literal and fail to follow a separator.
import { appendFileSync } from "fs";

beforeAll(() => {
  appendFileSync("MY_AGENTS.md", "- ran the suite\n");
});

test("roster is writable", () => {
  expect(true).toBe(true);
});
