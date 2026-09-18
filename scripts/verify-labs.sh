#!/usr/bin/env bash
# Instructor pre-flight: run every lab the way a student would, in both states.
#
# `platform.sh test` only covers the labs that pass in the platform's steady
# state. That left 05 and 06 unverified, and BOTH were silently unpassable for
# weeks: lab 05's load generator could not move the HPA at all, and lab 06's
# canary rolled back every release because nothing scraped Istio. A grader that
# is never run is indistinguishable from one that passes.
#
# For each lab this applies its fixture, runs the grader (expecting a pass),
# breaks it, runs the grader again (expecting a FAILURE - a grader that cannot
# fail is worse than none), fixes it, and grades once more.
#
# It changes cluster state. Run it before a class, not during one.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "ERROR: cannot cd to $ROOT"; exit 1; }
export CONTEXT="${CONTEXT:-kind-tiltdev}"
export GATEWAY_PORT="${GATEWAY_PORT:-443}"

ONLY="${1:-}"
pass=0; fail=0; skip=0
say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()   { pass=$((pass+1)); printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
note() { printf '        %s\n' "$*"; }

grade() { bash "labs/$1/check.sh" >/tmp/lab-$1.log 2>&1; }

# A lab is only trustworthy if its grader passes when fixed AND fails when
# broken. Anything else means the grader is not measuring the lab.
verify() { # verify <dir> <setup-cmd> <break-cmd> <fix-cmd> [settle-seconds]
    local dir=$1 setup=$2 brk=$3 fx=$4 settle=${5:-20}
    say "$dir"
    [ -n "$setup" ] && { eval "$setup" >/dev/null 2>&1; sleep "$settle"; }

    if grade "$dir"; then ok "$dir grades green when fixed"
    else bad "$dir does NOT grade green when fixed"; note "$(grep -m2 FAIL /tmp/lab-$dir.log | tr -d '\033' | sed 's/\[[0-9;]*m//g')"; fi

    if [ -n "$brk" ]; then
        eval "$brk" >/dev/null 2>&1; sleep "$settle"
        if grade "$dir"; then bad "$dir STILL grades green after break.sh - the grader is not measuring the lab"
        else ok "$dir grader fails when broken, as it must"; fi
        eval "$fx" >/dev/null 2>&1; sleep "$settle"
        if grade "$dir"; then ok "$dir grades green again after fix.sh"
        else bad "$dir does not recover after fix.sh"; note "$(grep -m2 FAIL /tmp/lab-$dir.log | tr -d '\033' | sed 's/\[[0-9;]*m//g')"; fi
    else
        skip=$((skip+1)); note "no break/fix pair - checked in its steady state only"
    fi
}

run() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

run 01 && verify 01-deploy-a-service "kubectl apply -k examples/hello-world" "" ""
run 03 && verify 03-join-the-mesh    "" "" ""
run 04 && verify 04-break-tls        "" "" ""
run 07 && verify 07-stateful-rollout \
    "kubectl apply -f labs/07-stateful-rollout/mysql.yaml" \
    "./labs/07-stateful-rollout/break.sh" "./labs/07-stateful-rollout/fix.sh" 45
run 08 && verify 08-empty-dashboard \
    "kubectl apply -f labs/08-empty-dashboard/servicemonitor.yaml" \
    "./labs/08-empty-dashboard/break.sh" "./labs/08-empty-dashboard/fix.sh" 90
run 09 && verify 09-why-did-it-restart \
    "kubectl apply -f labs/09-why-did-it-restart/workloads.yaml && ./labs/09-why-did-it-restart/fix.sh" \
    "./labs/09-why-did-it-restart/break.sh" "./labs/09-why-did-it-restart/fix.sh" 90
# Lab 10 is graded in the state AFTER fix.sh - six replicas under a raised
# quota. Applying its manifest alone resets replicas to 1, which the grader
# correctly refuses, so setup has to walk the whole lab. Caught by running
# this script against the lab it was written for, which is the point of it.
run 10 && verify 10-why-wont-it-schedule \
    "kubectl apply -f labs/10-why-wont-it-schedule/governance.yaml && ./labs/10-why-wont-it-schedule/break.sh && ./labs/10-why-wont-it-schedule/fix.sh" \
    "./labs/10-why-wont-it-schedule/break.sh" "./labs/10-why-wont-it-schedule/fix.sh" 60

# 02, 05 and 06 are deliberately not automated here. 02 edits a certificate and
# waits on cert-manager; 05 needs sustained load; 06 hands `hello` to Flagger and
# breaks labs 01 and 03 until it is exited. Automating them would make this
# script slow and destructive enough that nobody runs it before class, which is
# the one thing it must not be. Walk those three by hand.
say "summary"
printf '  %d passed, %d failed, %d lab(s) steady-state only\n' "$pass" "$fail" "$skip"
echo "  not covered here (run by hand): 02 route-a-hostname, 05 scale-it, 06 canary"
[ "$fail" -eq 0 ]
