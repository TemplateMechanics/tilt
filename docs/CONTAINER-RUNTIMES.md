# Container runtimes

kind needs a container daemon. Docker Desktop is the tested default, but nothing
in this repo depends on Docker Desktop specifically, and Podman works.

| Runtime | Status | Notes |
|---|---|---|
| Docker Desktop | **Tested** | The default. Everything in the labs and CI was built against it. |
| Podman | **Tested on Windows** | Needs `KIND_EXPERIMENTAL_PROVIDER=podman` and a kernel with `nft_fib_inet` — see below. |
| Rancher Desktop (dockerd) | Untested | Should work; it is a real dockerd. Nobody has run the labs on it. |
| Colima | Untested | The usual open-source choice on macOS. |
| Docker Engine CE in WSL2 | Untested | Avoids Docker Desktop licensing on Windows. |

"Untested" means exactly that: not known broken, never exercised. Do not put it
in front of a class without running `./scripts/platform.sh test` on it first.

## Running on Podman

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
./scripts/platform.sh up
```

To run a Podman cluster **beside** an existing Docker one, give it its own name
and ports so the two do not collide in your kubeconfig or on 443:

```bash
CLUSTER=tiltdev-podman KIND_CONFIG=kind/cluster-alt-ports.yaml \
  GATEWAY_PORT=8443 TILT_PORT=10360 KIND_EXPERIMENTAL_PROVIDER=podman \
  ./scripts/platform.sh up
```

`TRUST_CA=0` skips installing that cluster's root CA into your OS trust store.
Use it for a throwaway cluster: every cluster mints its own CA, and on Windows
removing one needs a GUI confirmation that cannot be scripted.

Be aware of what that costs. The lab graders and `./scripts/platform.sh check`
verify TLS against the **OS trust store on purpose**, with no `-k` and no
explicit CA, because a lab about broken certificates is worthless if the check
bypasses certificate checking. So on a `TRUST_CA=0` cluster their HTTP
assertions fail by design:

```
ok    TLS for hello.localhost verifies (code 0)      <- uses the cluster CA explicitly
FAIL  GET https://hello.localhost:8443/ -> 000       <- OS store does not trust it
FAIL  browser check: ERR_CERT_AUTHORITY_INVALID      <- same cause
```

Confirm such a cluster by hand with the CA passed in, and read the body rather
than the status code:

```bash
kubectl get secret local-root-ca -n cert-manager   -o go-template='{{index .data "tls.crt"}}' | base64 -d > /tmp/ca.crt
curl --ssl-no-revoke --cacert /tmp/ca.crt   --resolve hello.localhost:8443:127.0.0.1 https://hello.localhost:8443/
```

Run the graders on a cluster whose CA you did trust.

## The Podman kernel requirement

Podman's network backend, netavark 2.x, builds a single `inet netavark`
nftables table whose NAT chains begin with `fib daddr type local`. A kernel
without the `nft_fib_inet` module cannot apply that ruleset, so **no bridge
network can be created at all** and kind never gets off the ground.

The failure is nearly unsearchable, which is why `platform.sh up` now checks for
the module before creating a cluster. netavark reads the kernel's "No such file
or directory" as "the table does not exist yet", swallows it, and podman prints:

```
Error: netavark (exit code 1): nftables error: "nft" did not return successfully while applying ruleset:
```

with nothing after the colon.

**On Windows** the kernel that matters is WSL's, not Windows'. WSL kernel
6.6.87.2 was built with `# CONFIG_NFT_FIB_IPV6 is not set` and no
`CONFIG_NFT_FIB_INET`, so Podman could not create a network at all. WSL 2.7.13
ships kernel 6.18.33.2, which has both. Fix:

```powershell
wsl --update      # needs an elevated terminal
wsl --shutdown    # the new kernel is picked up on next boot
```

Check what you have with `wsl --version`, or directly:

```bash
podman machine ssh -- modinfo nft_fib_inet
```

Netavark 2.x removed the iptables firewall driver, so on an affected kernel
there is no configuration that works: `firewall_driver = "iptables"` is
rejected outright, `firewalld` fails on the same `fib` expression, and `none`
gives you a bridge with no NAT and no port publishing. Pinning back to Podman
5.x with Netavark 1.x does work, but it is a pin, not a fix, and `podman machine
rm` loses it. Update the kernel instead.
