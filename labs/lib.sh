#!/usr/bin/env bash
# Shared assertions for lab graders. Source it: `. "$(dirname "$0")/../lib.sh"`
#
# Every grader is a list of assertions that each name the thing they checked.
# A grader that cannot fail is worse than none, so every lab's check.sh is run
# once against a deliberately broken state before it is trusted — see
# labs/README.md. Keep assertions specific: "pod Ready" and "HTTP 200" are
# different facts, and a lab can pass one while failing the other.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${CONTEXT:-kind-tiltdev}"
GATEWAY_PORT="${GATEWAY_PORT:-443}"
K="kubectl --context ${CONTEXT}"

_pass=0; _fail=0
pass() { _pass=$((_pass+1)); printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { _fail=$((_fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
note() { printf '        %s\n' "$*"; }

# ":443" is implicit; only append a non-standard gateway port.
url() { # url <host> [path]
    local p=""; [ "$GATEWAY_PORT" != "443" ] && p=":${GATEWAY_PORT}"
    echo "https://$1${p}${2:-/}"
}

# curl through the gateway. --resolve pins the hostname to loopback so the
# check does not depend on OS resolver behaviour for *.localhost. Functional
# HTTP assertions verify against the platform CA explicitly: current macOS curl
# builds can use /etc/ssl/cert.pem even when Chrome and Security.framework use
# the login keychain, which otherwise makes a healthy route fail for an
# unrelated client trust-store choice. OS trust is tested separately below.
gw() ( # gw <host> [path] [extra curl args...]
    local host="$1" path="${2:-/}" ca; shift 2 2>/dev/null || shift $#
    ca="$(mktemp -t lab-gateway-ca-XXXXXX)"
    trap 'rm -f "$ca"' EXIT
    $K get secret local-root-ca -n cert-manager \
        -o go-template='{{index .data "tls.crt"}}' 2>/dev/null | base64 -d > "$ca"
    if [ ! -s "$ca" ] || ! openssl x509 -in "$ca" -noout >/dev/null 2>&1; then
        echo "ERROR: cluster root CA is empty or invalid" >&2
        return 1
    fi
    curl -sS --max-time 20 --cacert "$ca" \
        --resolve "${host}:${GATEWAY_PORT}:127.0.0.1" "$@" "$(url "$host" "$path")"
)

# Prove that the host-native trust store accepts the live endpoint. On macOS,
# Security.framework is authoritative for both the login keychain and Chrome's
# locally installed anchors; curl may instead read /etc/ssl/cert.pem. Requiring
# revocation here also exercises the local CRLs on managed Macs. Other platforms
# retain curl's native trust-store check.
assert_os_trust() { # assert_os_trust <host>
    local host="$1" code
    case "$(uname -s)" in
      Darwin)
        if security verify-cert -R require "$(url "$host" /)" >/dev/null 2>&1; then
            pass "macOS trust store accepts $host with required revocation checking"
        else
            fail "macOS trust store rejects $host or cannot obtain revocation status"
        fi
        ;;
      *)
        code=$(curl -sS --max-time 15 \
            --resolve "${host}:${GATEWAY_PORT}:127.0.0.1" \
            -o /dev/null -w '%{http_code}' "$(url "$host" /)" 2>/dev/null)
        code="${code:-000}"
        if [ "$code" = "000" ]; then
            fail "OS trust store rejects the chain or the endpoint is unreachable"
        else
            pass "OS trust store accepts the chain (no --cacert; HTTP $code)"
        fi
        ;;
    esac
}

assert_http() { # assert_http <host> <path> <expected-code>
    # curl prints 000 itself on a connection failure and then exits non-zero;
    # appending a fallback produced "000000". Default only when truly empty.
    local code; code=$(gw "$1" "$2" -o /dev/null -w '%{http_code}' 2>/dev/null); code="${code:-000}"
    [ "$code" = "$3" ] && pass "GET $(url "$1" "$2") -> $3" || fail "GET $(url "$1" "$2") -> $code (wanted $3)"
}

assert_body_contains() { # assert_body_contains <host> <path> <substring>
    local body; body=$(gw "$1" "$2" 2>/dev/null || true)
    case "$body" in *"$3"*) pass "body of $(url "$1" "$2") contains \"$3\"" ;;
                     *) fail "body of $(url "$1" "$2") lacks \"$3\"" ;; esac
}

# openssl verify return codes distinguish the two ways TLS fails, which look
# identical in a browser: 62 = hostname mismatch (cert is trusted, wrong name),
# 18/19/20/21 = trust failure (chain does not reach a trusted root).
tls_verify_code() { # tls_verify_code <host>
    # The CA goes to a temp file, not a <(...) process substitution: openssl
    # under Git Bash cannot open /dev/fd/N, -CAfile silently fails, and the
    # grep finds no "Verify return code" line at all — so the helper returned
    # "?" for every host and both TLS labs failed in their FIXED state.
    local ca; ca="$(mktemp -t lab-ca-XXXXXX)"
    $K get secret local-root-ca -n cert-manager -o go-template='{{index .data "tls.crt"}}' 2>/dev/null | base64 -d > "$ca"
    echo | openssl s_client -connect "127.0.0.1:${GATEWAY_PORT}" -servername "$1" -verify_hostname "$1" -CAfile "$ca" 2>/dev/null         | grep -oE "Verify return code: [0-9]+" | grep -oE "[0-9]+$" || echo "?"
    rm -f "$ca"
}

assert_tls_ok()       { local c; c=$(tls_verify_code "$1"); [ "$c" = "0" ]  && pass "TLS for $1 verifies (code 0)"            || fail "TLS for $1 verify code $c (wanted 0)"; }
assert_tls_mismatch() { local c; c=$(tls_verify_code "$1"); [ "$c" = "62" ] && pass "TLS for $1 is a HOSTNAME MISMATCH (62)" || fail "TLS for $1 verify code $c (wanted 62 = hostname mismatch)"; }

assert_san_present() { # assert_san_present <host>  — on the cert actually served
    if echo | openssl s_client -connect "127.0.0.1:${GATEWAY_PORT}" -servername "$1" 2>/dev/null \
        | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:$1\b"; then
        pass "served certificate lists $1"; else fail "served certificate does not list $1"; fi
}
assert_san_absent() {
    if echo | openssl s_client -connect "127.0.0.1:${GATEWAY_PORT}" -servername "$1" 2>/dev/null \
        | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:$1\b"; then
        fail "served certificate still lists $1"; else pass "served certificate does not list $1"; fi
}

assert_ready() { # assert_ready <ns> <deploy>
    local r; r=$($K -n "$1" get deploy "$2" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    [ "${r:-0}" -ge 1 ] && pass "$1/$2 has $r ready replica(s)" || fail "$1/$2 has no ready replicas"
}

assert_replicas_at_least() { # <ns> <deploy> <n>
    local r; r=$($K -n "$1" get deploy "$2" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    [ "${r:-0}" -ge "$3" ] && pass "$1/$2 ready replicas $r >= $3" || fail "$1/$2 ready replicas ${r:-0} < $3"
}

assert_route_accepted() { # <ns> <httproute>
    local s; s=$($K -n "$1" get httproute "$2" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
    [ "$s" = "True" ] && pass "HTTPRoute $1/$2 Accepted by the Gateway" || fail "HTTPRoute $1/$2 not Accepted (status: '${s:-none}')"
}

# Dotted keys (istio.io/dataplane-mode) are read with go-template `index`, not
# jsonpath. jsonpath needs the dots escaped and the escaping did not survive
# the shell layers, so lab 03 reported the label missing while it was plainly
# set. go-template needs no escaping at all.
assert_ns_label() { # <ns> <label> <value>
    local v; v=$($K get ns "$1" -o go-template="{{index .metadata.labels \"$2\"}}" 2>/dev/null)
    [ "$v" = "$3" ] && pass "namespace $1 has $2=$3" || fail "namespace $1 has $2='${v:-<unset>}' (wanted $3)"
}

assert_pod_annotation() { # <ns> <selector> <annotation> <value>
    local v; v=$($K -n "$1" get pods -l "$2" -o go-template="{{range .items}}{{index .metadata.annotations \"$3\"}}{{break}}{{end}}" 2>/dev/null)
    [ "$v" = "$4" ] && pass "pod $1 [$2] has $3=$4" || fail "pod $1 [$2] has $3='${v:-<unset>}' (wanted $4)"
}

assert_metrics_api() {
    $K top nodes >/dev/null 2>&1 && pass "Metrics API answers (kubectl top nodes)" || fail "Metrics API not available"
}

assert_strategy() { # <ns> <deploy> <Recreate|RollingUpdate>
    local s; s=$($K -n "$1" get deploy "$2" -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
    [ "$s" = "$3" ] && pass "$1/$2 strategy is $3" || fail "$1/$2 strategy is '${s:-<unset>}' (wanted $3)"
}

assert_pod_count() { # <ns> <selector> <n>
    local n; n=$($K -n "$1" get pods -l "$2" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -eq "$3" ] && pass "$1 [$2] has exactly $3 pod(s)" || fail "$1 [$2] has $n pod(s) (wanted $3)"
}

# Render in a real browser via the harness. Proves the page is not an empty
# shell, which a status code cannot.
assert_browser() { # <service-name from services.json>
    if (cd "$ROOT" && GATEWAY_PORT="$GATEWAY_PORT" ./scripts/platform.sh check --only "$1" >/tmp/lab-browser.log 2>&1); then
        pass "renders in Chrome: $(grep -E '^(OK|WARN)' /tmp/lab-browser.log | head -1 | sed 's/  */ /g')"
    else fail "browser check: $(grep -E '^FAIL' /tmp/lab-browser.log | head -1 | sed 's/  */ /g')"; fi
}

wait_for() { # wait_for <seconds> <description> <command...>
    # The description used to be accepted and thrown away, so a lab could sit
    # silent for two minutes waiting on a certificate reissue and look hung.
    # It is printed once, on the first iteration that actually has to wait, so
    # a condition that is already true stays quiet.
    local t=$1 d=$2; shift 2; local end=$((SECONDS+t)) announced=0
    until "$@" >/dev/null 2>&1 || [ "$SECONDS" -gt "$end" ]; do
        [ "$announced" -eq 0 ] && printf '        waiting for %s (up to %ss)...
' "$d" "$t"
        announced=1
        sleep 5
    done
    "$@" >/dev/null 2>&1
}

summary() {
    echo; printf '  %d passed, %d failed\n' "$_pass" "$_fail"
    [ "$_fail" -eq 0 ]
}
