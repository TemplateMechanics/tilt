# TLS Certificates

Certificates are issued by **cert-manager** inside the cluster. Nothing is
generated on the host and no key material is stored in the repo.

## The chain

```
ClusterIssuer/selfsigned-bootstrap        (bootstrap only)
  -> Certificate/local-root-ca            10y, ECDSA P-256, cert-manager ns
       -> ClusterIssuer/local-root-ca
            -> Certificate/local-intermediate-ca   5y
                 -> ClusterIssuer/local-intermediate-ca
                      -> Certificate/wildcard-localhost   90d, istio-system ns
                           -> Secret/wildcard-localhost-tls
```

The Gateway (`istio-system/localhost-gateway`) references that Secret through
`certificateRefs`, so every service gets TLS without naming a Secret of its own.

Leaf certs are signed by the intermediate, never the root, so rotating a leaf
never touches the CA installed in your OS trust store.

## Renewal

`renewBefore: 720h` (30 days) on a 90-day certificate. cert-manager renews
unattended and `rotationPolicy: Always` issues a fresh key each time.

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

The `dev-ca-trust` Tilt resource exports the root CA from the cluster Secret and
installs it in the OS trust store (macOS keychain, Linux
`/usr/local/share/ca-certificates`, Windows user Root store). It refuses to touch
the trust store if the export comes back empty, and prints the fingerprint.

Verify it took, rather than trusting the log line:

```bash
# Windows
powershell "Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Subject -like '*Tilt Local Development Root CA*' }"
# macOS
security find-certificate -c "Tilt Local Development Root CA" /Library/Keychains/System.keychain
# Linux
ls -l /usr/local/share/ca-certificates/dev-root-ca.crt
```

**Known gap:** if cert-manager is reinstalled, a new root CA is generated and the
OS store keeps the old one until `dev-ca-trust` runs again. Nothing currently
detects that mismatch; the symptom is a browser trust warning on a platform that
otherwise looks healthy. Re-trigger `dev-ca-trust` in Tilt to resolve it.

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
