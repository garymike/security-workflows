// A perfectly ordinary unit test bundled with a skill. It touches no credentials, no network, and
// no shell. The gate's inventory layer notes that a test file is present (low severity), but the
// malice layer finds nothing, so the gate does NOT block. This fixture proves the presence->malice
// upgrade: legitimate bundled tests are no longer false-positived the way a filename-only gate would.
import { test, expect } from "vitest";

function slugify(s: string): string {
  return s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

test("lowercases and hyphenates", () => {
  expect(slugify("Hello World")).toBe("hello-world");
});

test("collapses separators and trims the ends", () => {
  expect(slugify("  Wave__Runner!!  ")).toBe("wave-runner");
});
