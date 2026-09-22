#!/usr/bin/env python3
"""Fail closed if the local PKI loses its revocation or hardening contract."""

import os
import subprocess
import sys

import yaml


def load(path):
    with open(path, encoding="utf-8") as fh:
        return [doc for doc in yaml.safe_load_all(fh) if isinstance(doc, dict)]


errors = []


def require(condition, message):
    if not condition:
        errors.append(message)


certs = {
    doc["metadata"]["name"]: doc
    for doc in load("helm/cert-manager/pki/base/certificates.yaml")
    if doc.get("kind") == "Certificate"
}
for name in ("local-root-ca", "local-intermediate-ca"):
    cert = certs.get(name, {})
    spec = cert.get("spec", {})
    usages = {usage.lower() for usage in spec.get("usages", [])}
    require(spec.get("isCA") is True, f"{name} must remain a CA")
    require("cert sign" in usages, f"{name} must permit certificate signing")
    require("crl sign" in usages, f"{name} must permit CRL signing")
    require(
        spec.get("privateKey", {}).get("rotationPolicy") == "Never",
        f"{name} must preserve its private key during metadata reissuance",
    )

issuers = {
    doc["metadata"]["name"]: doc
    for doc in load("helm/cert-manager/pki/base/cluster-issuers.yaml")
    if doc.get("kind") == "ClusterIssuer"
}
expected_dps = {
    "local-root-ca": ["http://crl.localhost/root.crl"],
    "local-intermediate-ca": ["http://crl.localhost/intermediate.crl"],
}
for name, expected in expected_dps.items():
    actual = issuers.get(name, {}).get("spec", {}).get("ca", {}).get(
        "crlDistributionPoints", []
    )
    require(actual == expected, f"{name} CRL distribution point must be {expected[0]}")

route = next(
    doc for doc in load("helm/cert-manager/crl/route.yaml") if doc.get("kind") == "HTTPRoute"
)
route_spec = route.get("spec", {})
require(route_spec.get("hostnames") == ["crl.localhost"], "CRL route must use only crl.localhost")
parents = route_spec.get("parentRefs", [])
require(
    parents and all(parent.get("sectionName") == "http" for parent in parents),
    "CRL route must attach only to the plaintext HTTP listener",
)
matches = route_spec.get("rules", [{}])[0].get("matches", [])
paths = {
    match.get("path", {}).get("value")
    for match in matches
    if match.get("path", {}).get("type") == "Exact"
}
require(paths == {"/root.crl", "/intermediate.crl"}, "CRL route paths must be exact and complete")

deployment = next(
    doc for doc in load("helm/cert-manager/crl/server.yaml") if doc.get("kind") == "Deployment"
)
pod = deployment.get("spec", {}).get("template", {}).get("spec", {})
container = pod.get("containers", [{}])[0]
security = container.get("securityContext", {})
require(pod.get("automountServiceAccountToken") is False, "CRL server must not mount an API token")
require(pod.get("securityContext", {}).get("runAsNonRoot") is True, "CRL server must run as non-root")
require(security.get("readOnlyRootFilesystem") is True, "CRL server root filesystem must be read-only")
require(security.get("allowPrivilegeEscalation") is False, "CRL server must forbid privilege escalation")
require(
    security.get("capabilities", {}).get("drop") == ["ALL"],
    "CRL server must drop every Linux capability",
)
require("@sha256:" in container.get("image", ""), "CRL server image must be pinned by digest")

# The alternate kind topology maps plaintext HTTP to 8080. Prove the renderer
# embeds that port before issuance instead of leaving an unreachable CDP.
environment = dict(os.environ, CRL_BASE_URL="http://crl.localhost:8080")
rendered = subprocess.run(
    ["bash", "scripts/apply-local-pki.sh", "--render"],
    check=True,
    capture_output=True,
    text=True,
    env=environment,
).stdout
rendered_docs = [doc for doc in yaml.safe_load_all(rendered) if isinstance(doc, dict)]
rendered_issuers = {
    doc["metadata"]["name"]: doc
    for doc in rendered_docs
    if doc.get("kind") == "ClusterIssuer"
}
for name, suffix in (("local-root-ca", "root.crl"), ("local-intermediate-ca", "intermediate.crl")):
    actual = rendered_issuers[name]["spec"]["ca"]["crlDistributionPoints"]
    require(
        actual == [f"http://crl.localhost:8080/{suffix}"],
        f"alternate-port rendering is wrong for {name}",
    )

print("Local PKI checks: 2 CAs, 2 CRL endpoints, hardened HTTP-only server")
if errors:
    for error in errors:
        print(f"  FAIL: {error}")
    sys.exit(1)
print("OK: local PKI revocation contract is complete")
