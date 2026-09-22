# TLS Certificates

Certificates are issued by **cert-manager** inside the cluster. The host creates
short-lived CRL artifacts from the live CA Secrets, but no generated certificate,
CRL, or private-key material is committed to the repo.

## The chain

```
ClusterIssuer/selfsigned-bootstrap        (bootstrap only)
  -> Certificate/local-root-ca            10y, ECDSA P-256, cert+CRL signing
       -> ClusterIssuer/local-root-ca
            -> Certificate/local-intermediate-ca   5y, CDP /root.crl
                 -> ClusterIssuer/local-intermediate-ca
                      -> Certificate/wildcard-localhost   90d, CDP /intermediate.crl
                           -> Secret/wildcard-localhost-tls

local-root-ca key          -> signs root.crl
local-intermediate-ca key  -> signs intermediate.crl
                               served at http://crl.localhost
```

The Gateway (`istio-system/localhost-gateway`) references that Secret through
`certificateRefs`, so every service gets TLS without naming a Secret of its own.

Leaf certs are signed by the intermediate, never the root, so rotating a leaf
never touches the CA installed in your OS trust store.

## Renewal

`renewBefore: 720h` (30 days) on a 90-day certificate. cert-manager renews
unattended and `rotationPolicy: Always` issues a fresh key each time.

The root and intermediate use `rotationPolicy: Never`: metadata reissuance can
add or update revocation information without silently replacing the host trust
anchor. `scripts/apply-local-pki.sh` applies issuers before certificates,
verifies both CAs can sign CRLs, verifies the intermediate's distribution
point, and fails if an existing root public key changes.

`scripts/ensure-local-crls.sh` generates fresh, empty development CRLs from the
live CA Secrets, publishes them through an HTTP-only Gateway route, and verifies
their signatures and the complete leaf chain with `-crl_check_all`. Generated
CRLs and CA private keys are never committed; temporary key copies are created
with restrictive permissions and removed on exit.

This is the main reason the OpenSSL scripts were retired: they regenerated only
when the chain file was *missing*, never when it had expired, so an expired
certificate was never noticed until TLS simply broke.

## Adding a hostname

Add it to `dnsNames` in `helm/istio/gateway/base/certificate.yaml`.

**The `*.localhost` wildcard is not enough on its own.** Verified on this
platform: both OpenSSL and Windows schannel reject `*.localhost` as a match for
`myapp.localhost`, because a wildcard directly beneath a single-label parent
(`localhost` behaves as a TLD) is not accepted.

```
openssl:  Verify return code: 62 (hostname mismatch)
schannel: CertGetNameString() failed to match connection hostname
```

Adding the explicit hostname makes the same request verify cleanly. The list
looks redundant and is not - deleting an entry breaks TLS for that service with
a hostname-mismatch error, which reads like a CA problem and sends you down the
wrong path.

## Trusting the CA

The `dev-ca-trust` Tilt resource runs only after the leaf and CRL endpoints are
ready. It exports the root CA from the cluster Secret and installs it in the OS
trust store (macOS user/login keychain, Linux
`/usr/local/share/ca-certificates`, Windows user Root store). It refuses to touch
the trust store if the export comes back empty or invalid, and prints the
fingerprint.

Verify it took, rather than trusting the log line:

```bash
# Windows
powershell "Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Subject -like '*Tilt Local Development Root CA*' }"
# macOS
security find-certificate -c "Tilt Local Development Root CA" "$HOME/Library/Keychains/login.keychain-db"
security verify-cert -R require https://hello.localhost/
# Linux
ls -l /usr/local/share/ca-certificates/dev-root-ca.crt
```

If a cluster reset mints a new root, `dev-ca-trust` compares the exact current
SHA-256 fingerprint rather than accepting an older same-name certificate. Run
`./scripts/trust-ca.sh` to reconcile host trust; `TRUST_CA=0` exports
`.local/dev-root-ca.crt` without changing the OS store. Old roots are not
deleted automatically because another local cluster may still use them.
`./scripts/trust-ca.sh --list` also reports legacy macOS System-keychain roots
created by older releases, without modifying them.

The CRL endpoint intentionally uses plaintext HTTP. A certificate cannot rely
on the certificate it is validating in order to retrieve its own revocation
status. The alternate kind topology embeds port 8080 in both distribution
points before certificates are issued.

## Inspecting what is actually served

```bash
# Chain and SANs on the wire
echo | openssl s_client -connect localhost:443 -servername grafana.localhost | \
  openssl x509 -noout -subject -issuer -dates -ext subjectAltName

# Certificate resources and their readiness
kubectl get certificate -A
kubectl get clusterissuer
```

## Legacy

The previous OpenSSL scripts are kept in `archive/openssl-certs/` for customers
still running them. See `archive/README.md`.
