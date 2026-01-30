#!/bin/bash

# Install Flux CLI if not already installed
if ! command -v flux &> /dev/null; then
    echo "Flux CLI not found. Installing..."
    curl -s https://fluxcd.io/install.sh | sudo bash
else
    echo "Flux CLI already installed"
fi

# Install Flux on the cluster
echo "Installing Flux on the cluster..."
flux install

# Wait for Flux to be ready
echo "Waiting for Flux to be ready..."
kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=kustomize-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=helm-controller -n flux-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=notification-controller -n flux-system --timeout=300s

echo "Flux installation complete!"
