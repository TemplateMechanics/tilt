#!/usr/bin/env python3
"""Every HTTPRoute hostname must be a SAN on the Gateway's certificate.

A hostname that is routed but not present in the certificate's dnsNames fails
TLS with a *hostname mismatch*, not a trust error — so the browser complains
about the certificate and the obvious next move is to go and debug the CA, which
is the wrong tree entirely.

The "*.localhost" wildcard does NOT cover this. Verified on the platform: both
OpenSSL and Windows schannel reject "*.localhost" as a match for
"myapp.localhost", because a wildcard directly beneath a single-label parent
("localhost" behaves as a TLD) is not accepted:

    openssl:  Verify return code: 62 (hostname mismatch)
    schannel: CertGetNameString() failed to match connection hostname

so each hostname needs its own entry. This check exists because adding a service
and forgetting the SAN is a one-line omission with a misleading symptom.
"""
import os
import sys
import glob

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

CERT = "helm/istio/gateway/base/certificate.yaml"
# examples/ is scanned too. It was not at first, and the check reported OK for
# examples/hello-world with its hostname absent from the certificate — a false
# clean, which is worse than no check because it reads as evidence.
SEARCH = ["helm/**/*.yaml", "apps/**/*.yaml", "examples/**/*.yaml"]
# The scaffolder skeleton is a Jinja template, not valid YAML.
SKIP_SUBSTR = ("/skeleton/", "/node_modules/", "archive/")


def load_docs(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]
    except Exception:
        return []


def main():
    if not os.path.exists(CERT):
        sys.exit("FAIL: certificate not found at %s" % CERT)

    cert_docs = load_docs(CERT)
    dns = set()
    for d in cert_docs:
        if d.get("kind") == "Certificate":
            dns.update(d.get("spec", {}).get("dnsNames", []) or [])
    if not dns:
        sys.exit("FAIL: no dnsNames parsed from %s" % CERT)

    seen, missing = 0, []
    for pattern in SEARCH:
        for path in glob.glob(pattern, recursive=True):
            if any(s in path.replace("\\", "/") for s in SKIP_SUBSTR):
                continue
            for doc in load_docs(path):
                if doc.get("kind") != "HTTPRoute":
                    continue
                for host in doc.get("spec", {}).get("hostnames", []) or []:
                    seen += 1
                    if host not in dns:
                        missing.append((host, path))

    print("HTTPRoute hostnames checked: %d" % seen)
    print("Certificate dnsNames:        %d" % len(dns))

    if missing:
        print("\nFAIL: %d hostname(s) routed but absent from the certificate:" % len(missing))
        for host, path in sorted(missing):
            print("  %-34s %s" % (host, path))
        print("\nAdd them to spec.dnsNames in %s." % CERT)
        print('Note: "*.localhost" does not satisfy this - see the comment in that file.')
        return 1

    print("OK: every routed hostname has a matching SAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
