#!/usr/bin/env bash
# Two different fixes, because they are two different bugs.
. "$(dirname "$0")/../lib.sh"

# starved: give it enough memory. Nothing about probes would have helped.
$K -n lab09 patch deploy starved --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"512Mi"}]' >/dev/null
echo "starved:   memory limit 64Mi -> 512Mi"

# impatient: a startupProbe. It holds the liveness probe off until the container
# has actually started, instead of racing it. Raising the memory limit would
# have done nothing at all here - which is the point of the lab.
$K -n lab09 patch deploy impatient --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/startupProbe","value":{"httpGet":{"path":"/","port":8080},"periodSeconds":5,"failureThreshold":24}}]' >/dev/null
echo "impatient: added a startupProbe (up to 120s to start, then liveness takes over)"
echo
echo "waiting for both to settle..."
# `rollout status`, not readyReplicas. readyReplicas hits 1 while the previous
# ReplicaSet's pod is still terminating, and the grader - correctly - wants one
# pod from the current ReplicaSet. On a cold node, where image pulls are slow,
# that gap is wide enough that this script returned before the lab was fixed
# and the grader then failed a lab that was on its way to being right.
$K -n lab09 rollout status deploy/starved --timeout=300s
$K -n lab09 rollout status deploy/impatient --timeout=300s
$K -n lab09 get pods
