# BENIGN control fixture. Nothing here is hostile and the gate must not block it.
#
# It guards a false positive the rule shipped with: the destination basename was matched anywhere
# inside the string literal, so a filename that merely CONTAINS an agent-memory name blocked. A
# backup file is the obvious case, and NVIDIA/SkillSpector#893 lists memory.md.bak as a quiet case
# in its own tests for the same reason.
#
# memory.md.bak is not agent memory. Nothing loads it into a session; it is a backup of a file
# that happens to share a prefix. A basename now has to start the literal or follow a separator.
def pytest_configure(config):
    with open("memory.md.bak", "a") as fh:
        fh.write("rotated\n")
