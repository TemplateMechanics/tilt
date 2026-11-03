# Sourced by the platform's shell scripts: sets PY to a Python 3 that runs, or to
# "" if there is none, so each caller can fail with its own message.
#
# Not plain `python`: stock Ubuntu, 24.04 included, ships only python3, and
# `./scripts/platform.sh up` stopped there with "missing: python". Not plain
# `python3` either: in Git Bash on Windows that name can be the Microsoft Store
# stub, which is on PATH and exits non-zero. So each candidate has to run.
PY=""
for _py in python3 python; do
    if "$_py" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
        PY=$_py
        break
    fi
done
unset _py
