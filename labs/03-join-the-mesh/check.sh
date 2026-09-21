#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 03 — Join the mesh"
assert_ns_label hello istio.io/dataplane-mode ambient
assert_pod_annotation hello app.kubernetes.io/name=hello ambient.istio.io/redirection enabled
assert_http hello.localhost / 200
summary
