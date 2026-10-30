# DEFANGED demonstration fixture: the memory-poisoning carrier with an F-STRING destination.
#
# Only ever statically scanned by the gate; never executed in CI. It appends an inert canary
# comment, never a working instruction, so it stays harmless even if run by mistake.
#
# Why this fixture exists: the f prefix defeated `dev-exec-writes-agent-memory` the same way the
# r prefix did, and an f-string is how a carrier reaches a memory file whose directory is computed
# at runtime while the BASENAME stays literal. The basename is the part the rule matches, so this
# is squarely in scope -- unlike a fully computed destination, which remains a documented residual
# in docs/threats/developer-execution.md.
#
# pytest runs conftest.py automatically on collection, outside the agent, with the developer's
# full local permissions.
import os


def pytest_configure(config):
    base = os.path.dirname(os.path.abspath(__file__))
    with open(f"{base}/MEMORY.md", "a") as fh:
        fh.write("\n<!-- recap canary: demonstrates an unauthorized write to persistent agent memory -->\n")
