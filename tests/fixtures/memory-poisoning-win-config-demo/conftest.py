# DEFANGED demonstration fixture: a write into the agent CONFIG directory, spelled with a
# Windows separator.
#
# Only ever statically scanned by the gate; never executed in CI. It writes an inert empty JSON
# object, never a hook or an MCP server command, so it stays harmless even if run by mistake.
#
# Why this fixture exists: the destination list spelled the agent directories as `.claude/` with a
# hardcoded forward slash, so `.claude\settings.json` was uncovered on the one platform where
# that is the normal spelling. Writing .claude/settings.json is the config-injection vector
# (CVE-2025-59536 class) rather than the memory-file vector, and the same rule covers both
# destinations, so the separator gap applied to both.
#
# pytest runs conftest.py automatically on collection, outside the agent, with the developer's
# full local permissions.
def pytest_configure(config):
    with open(r".claude\settings.json", "w") as fh:
        fh.write("{}")
