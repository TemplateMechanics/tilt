#!/usr/bin/env python3
"""Fail if a shell script people run as ./path/to/it.sh is not executable in git.

Every README here says `./scripts/platform.sh up` or `./labs/NN-*/fix.sh`. That
works only if git records mode 100755. On Windows core.fileMode is false, so a
new script is committed as 100644 and Git Bash runs it anyway - nothing on the
machine that wrote it looks wrong.

This is not hypothetical: every script in scripts/ and labs/ except one was
100644, including platform.sh. In a fresh Linux clone the README's first command
printed `sh: ./scripts/platform.sh: Permission denied`. The shellcheck job
lints scripts without executing them, so CI stayed green. It was found by
checking that the commands the docs tell people to run actually run.

It reads the index (`git ls-files -s`), not the working tree, because the
working tree on the machine that introduced the bug says the files are fine.
"""
import subprocess
import sys

out = subprocess.run(
    ["git", "ls-files", "-s", "--", "scripts/*.sh", "labs/*.sh", "labs/*/*.sh"],
    capture_output=True, text=True, check=True,
).stdout

bad = []
checked = 0
for line in out.splitlines():
    mode, _, _, path = line.split(maxsplit=3)
    # lib.sh is sourced, never executed, and is correct without the bit.
    if path.endswith("/lib.sh"):
        continue
    checked += 1
    if mode != "100755":
        bad.append((mode, path))

print(f"Shell scripts checked: {checked}")
if bad:
    for mode, path in bad:
        print(f"  NOT EXECUTABLE ({mode}): {path}")
    print("Fix: git update-index --chmod=+x <file>   (chmod alone does nothing on Windows)")
    sys.exit(1)
print("OK: every runnable script is executable in git")
