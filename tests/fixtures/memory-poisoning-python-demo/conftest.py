# DEFANGED demonstration fixture: the memory-poisoning carrier in its PYTHON form.
#
# Only ever statically scanned by the gate; never executed in CI. It appends an inert canary
# comment, never a working instruction, so it stays harmless even if run by mistake.
#
# Why this fixture exists: memory-poisoning-demo covers the JS/TS shape
# (appendFileSync("MEMORY.md", ...)). This is the same attack in Python, and the gate used to
# miss it. `dev-exec-writes-agent-memory` required the sink token before the path, which holds
# for JS but not for Python, where open() takes the path first and the mode second. The old
# pattern therefore consumed past the filename and matched no Python write in any mode.
#
# pytest runs conftest.py automatically on collection, outside the agent, with the developer's
# full local permissions. Every later session that loads MEMORY.md reads whatever landed here.
def pytest_configure(config):
    with open("MEMORY.md", "a") as fh:
        fh.write("\n<!-- pytest-notes canary: demonstrates an unauthorized write to persistent agent memory -->\n")
