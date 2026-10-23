# Kyverno policies

Twelve Pod Security Standard policies, adapted from the Kyverno project's policy
library (see [Origin and licence](#origin-and-licence)). **Every one is in
`audit` mode, so none of them blocks anything.**

That is deliberate, and it is written down here because a policy that reports
and never refuses looks exactly like a policy that protects you. On this
platform you can confirm it in one command:

```bash
kubectl get clusterpolicy -o custom-columns=\
'NAME:.metadata.name,ACTION:.spec.validationFailureAction'
```

Every row says `audit`. A violating pod is admitted, a `PolicyReport` is
written, and the pod runs. Policy Reporter renders those reports; nothing
consumes them automatically.

## Why audit and not enforce

Enforce mode would reject the platform's own workloads. The components below
legitimately need what these policies forbid. Note this table is **reasoned from
the policy rules and the pod specs, not measured** — Kyverno ships disabled in
`tilt-config.json`, so no PolicyReport has been generated to confirm it. Enable
Kyverno and read the actual reports before trusting the list:

| Component | Needs | Policy it violates |
|---|---|---|
| `istio-cni-node`, `ztunnel` | privileged, host network, host paths | `disallow-privileged-containers`, `disallow-host-namespaces`, `disallow-host-path` |
| `alloy`, `wazuh-filebeat` | host paths for log collection | `disallow-host-path` |
| kind's `local-path-provisioner` | host paths for volumes | `disallow-host-path` |

Turning enforce on without exclusions breaks the mesh and log collection, which
is a worse lesson than a permissive default.

## Turning one on, which is the point

The interesting exercise is to enforce exactly one policy and watch what stops
working:

```bash
kubectl patch clusterpolicy disallow-privileged-containers \
  --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
kubectl -n hello delete pod -l app.kubernetes.io/name=hello   # still fine
kubectl -n istio-system rollout restart daemonset/ztunnel     # now refused
```

The refusal names the policy and the rule. Put it back with `"Audit"`.

Kyverno itself is `enabled: false` in `tilt-config.json`. Nothing in this
directory is running unless you turn it on.

## Origin and licence

These policies are adapted from the Kyverno project's Pod Security Standards
(Baseline) policies, <https://github.com/kyverno/policies/tree/release-1.19/pod-security/baseline>, copyright The Kyverno Authors. They
remain under the Apache License 2.0
(<https://www.apache.org/licenses/LICENSE-2.0>), not this repository's MIT licence,
and each file carries a notice that it was modified.

Changes from the upstream versions:

- Every policy is set to `audit`. Upstream `restrict-apparmor-profiles` uses
  `Enforce`; the others use `Audit`.
- The `kyverno.io/kyverno-version` and `kyverno.io/kubernetes-version`
  annotations were changed.
- `disallow-capabilities`, `disallow-host-namespaces`, `disallow-host-path`,
  `disallow-host-ports`, `disallow-host-ports-range`, `disallow-host-process` and
  `disallow-privileged-containers` exclude the `kube-system` and `grafana`
  namespaces.
- YAML indentation and description line-wrapping differ.
