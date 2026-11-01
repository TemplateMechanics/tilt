#!/bin/bash

# The CLI is the pin (FLUX_VERSION in tilt/lib.tilt): `flux install` deploys
# the controllers built into the CLI running it, and a CLI refuses
# `--version` for any other minor version.
want=2.9.5
if ! command -v flux &> /dev/null; then
    echo "Flux CLI not found. Installing v$want..."
    curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION="$want" bash
fi
have=$(flux version --client 2>/dev/null | sed -n 's/^flux: *v//p')
if [ "$have" != "$want" ]; then
    echo "ERROR: Flux CLI is ${have:-unknown}; this platform pins v$want." >&2
    echo "  curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION=$want bash" >&2
    exit 1
fi

echo "Installing Flux v$want on the cluster..."
flux install

# Wait for Flux to be ready
echo "Waiting for Flux to be ready..."
kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=kustomize-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=helm-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=notification-controller -n flux-system --timeout=300s

echo "Flux installation complete!"
