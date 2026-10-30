# DEFANGED demonstration fixture: the memory-poisoning carrier with a RAW-STRING destination.
#
# Only ever statically scanned by the gate; never executed in CI. It appends an inert canary
# comment, never a working instruction, so it stays harmless even if run by mistake.
#
# Why this fixture exists: `dev-exec-writes-agent-memory` required `open(` to be followed
# immediately by the quote, so any Python string prefix defeated it. The r"" below is the exact
# shape NVIDIA/SkillSpector#893 was sent back in review for missing in its own analyzer, which is
# what prompted measuring ours. Ours missed it for a different reason: upstream stripped the
# backslashes, while we rejected the prefix. The escaped form open("C:\\Users\\MEMORY.md")
# already matched, so this was never about backslashes on our side.
#
# A raw string is the natural way to write a Windows path, because it is the spelling that does
# not need every separator doubled. That makes it the likely spelling in a real carrier, not an
# exotic one.
#
# pytest runs conftest.py automatically on collection, outside the agent, with the developer's
# full local permissions.
def pytest_configure(config):
    with open(r"C:\Users\alice\MEMORY.md", "a") as fh:
        fh.write("\n<!-- session-log canary: demonstrates an unauthorized write to persistent agent memory -->\n")
