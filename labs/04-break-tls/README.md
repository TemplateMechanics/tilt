# Lab 04 — Break TLS two different ways

**Profile:** minimal · **Time:** 20 min · **You will learn:** to tell a
hostname mismatch from a trust failure by how they fail, not by what the
browser says (it says the same thing for both).

## Break it, way one: wrong name

```
./labs/04-break-tls/break.sh mismatch
```

This removes `hello.localhost` from the certificate; cert-manager reissues
within ~30 s. Reload <https://hello.localhost>: certificate error.

```
./labs/04-break-tls/probe.sh hello.localhost
#   Verify return code: 62 (hostname mismatch)
```

The chain is fine. The name is wrong. Fix: put the SAN back.

## Break it, way two: wrong trust

First put the SAN back so only one thing is wrong at a time:

```
./labs/04-break-tls/fix.sh
```

Now see the *other* failure without touching your trust store:

```
./labs/04-break-tls/probe.sh hello.localhost --untrusted
#   Verify return code: 20 (unable to get local issuer certificate)
```

That verifies with no trusted CAs at all — what a machine that has never
trusted this platform's CA sees. The name is fine. Nothing trusts the chain.

To break it for real (macOS/Linux only — see below):

```
./labs/04-break-tls/break.sh trust
```

Reload the page: certificate error — **the same words in the browser** as
way one. Fix with `./labs/04-break-tls/fix.sh`, which calls the same shared
user-trust script as the Tilt resource `dev-ca-trust` and verifies online
revocation before reporting success.

> **Windows:** deleting from the user Root store always raises a GUI
> confirmation, so `break.sh trust` refuses and prints the manual command
> instead. Use `--untrusted` for the automated version of this step.

## Understand

A `401` from an application and a `connection reset` from a firewall look
alike in a test and mean opposite things. TLS has the same trap. The verify
code is the tell: **62** means "go edit the certificate"; **18–21** mean "go
fix the trust store". Debugging the wrong one is an afternoon gone.

## Check

```
./labs/04-break-tls/fix.sh && ./scripts/platform.sh lab 04
```
