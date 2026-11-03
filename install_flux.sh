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
    echo "  The flux on your PATH: $(command -v flux)" >&2
    echo "  curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION=$want bash" >&2
    echo "  If that path is Homebrew's: brew uninstall flux, then the line above" >&2
    exit 1
fi

# Each step stops the script on failure: without that, a failed install or a
# controller that never started still ended with "Flux installation complete!".
echo "Installing Flux v$want on the cluster..."
flux install || { echo "ERROR: flux install failed (output above)" >&2; exit 1; }

echo "Waiting for Flux to be ready..."
for c in source-controller kustomize-controller helm-controller notification-controller; do
    kubectl wait --for=condition=ready pod -l app=$c -n flux-system --timeout=300s || {
        echo "ERROR: $c did not become ready in 300s" >&2
        kubectl -n flux-system get pods >&2
        exit 1
    }
done

echo "Flux installation complete!"
