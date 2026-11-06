# Headlamp: the learner's cluster view

Headlamp is the visual Kubernetes resource explorer at **https://headlamp.localhost**.
It is installed by `tilt/core.tilt` for **every profile**, including `minimal`.
It is not a Helm release editor, and the learner account intentionally cannot
modify cluster objects or read Kubernetes Secrets, ConfigMaps or pod logs.

## Sign in safely

From the local kind cluster's trusted workstation, generate a short-lived token:

```bash
kubectl -n headlamp create token headlamp-learner --duration=1h
```

Paste it into the Headlamp login prompt. Never put the token in a screenshot,
recording, shell script, repository, or public post. Keep the browser restricted
to your development workstation; do not forward this URL to a shared network.

Verify privileges before presenting a session:

```bash
kubectl auth can-i list pods -A --as=system:serviceaccount:headlamp:headlamp-learner # yes
kubectl auth can-i get secrets -A --as=system:serviceaccount:headlamp:headlamp-learner # no
kubectl auth can-i patch deployments -A --as=system:serviceaccount:headlamp:headlamp-learner # no
```

Headlamp's own authentication remains on. The chart and namespace already existed;
this change makes the viewer consistently available to beginners, and provides
an explicitly scoped demo identity instead of a cluster-admin token.

To check the installation without claiming mere presence is sufficient:

```bash
kubectl -n headlamp wait --for=condition=Ready helmrelease/headlamp --timeout=600s
kubectl -n headlamp rollout status deployment/headlamp --timeout=180s
kubectl -n headlamp get httproute headlamp -o yaml
```

For local clusters using the alternate Gateway port, use
`https://headlamp.localhost:8443`.
