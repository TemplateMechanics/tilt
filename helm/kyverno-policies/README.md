# Kyverno policies

Fourteen Pod Security Standard policy files. Twelve are live and **every live
one is in `audit` mode, so none of them blocks anything**. The remaining two
(`add-host-aliases.yaml`, `add-resource-limits.yaml`) are commented out in full
and are not applied at all.

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

The two commented-out files are mutating policies, and a mutation that fires on
every pod in the cluster is not something to switch on without reading it first.

Kyverno itself is `enabled: false` in `tilt-config.json`. Nothing in this
directory is running unless you turn it on.
