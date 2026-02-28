#!/usr/bin/env bash
###############################################################################
# cleanup-disabled-apps.sh
#
# Cleans up Kubernetes resources for disabled Tilt apps. Called by the Tiltfile
# instead of inlining the entire cleanup command (which exceeds Windows/Git
# Bash command-length limits).
#
# Usage:
#   cleanup-disabled-apps.sh \
#       --crossplane-apps "app1 app2" \
#       --namespaces "ns1 ns2" \
#       --disabled-raw "app1 app2" \
#       --disabled-flux "app1 app2"
#
# All flags are optional; omit any that have no items.
###############################################################################
set -euo pipefail

CROSSPLANE_APPS=""
NAMESPACES=""
DISABLED_RAW=""
DISABLED_FLUX=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --crossplane-apps) CROSSPLANE_APPS="$2"; shift 2 ;;
        --namespaces)      NAMESPACES="$2";      shift 2 ;;
        --disabled-raw)    DISABLED_RAW="$2";     shift 2 ;;
        --disabled-flux)   DISABLED_FLUX="$2";    shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

# Helper: check if a word is in a space-separated list
contains() {
    local list="$1" item="$2"
    for w in $list; do
        [[ "$w" == "$item" ]] && return 0
    done
    return 1
}

###############################################################################
# Phase 3a — Crossplane DevApplication CR cleanup
###############################################################################
if [[ -n "$CROSSPLANE_APPS" ]]; then
    echo "Cleaning up Crossplane DevApplication CRs..."
    for app in $CROSSPLANE_APPS; do
        kubectl delete devapplication "$app" -n default \
            --ignore-not-found --wait=false 2>/dev/null || true
    done
    echo "Waiting for Crossplane cascade-delete (10s)..."
    sleep 10
fi

###############################################################################
# Phase 3b — Namespace deletion
###############################################################################
if [[ -n "$NAMESPACES" ]]; then
    echo "Deleting disabled namespaces..."
    for ns in $NAMESPACES; do
        kubectl delete namespace "$ns" \
            --ignore-not-found --wait=false 2>/dev/null || true
    done
fi

###############################################################################
# Phase 3c — Force-clear stuck Terminating namespaces
###############################################################################
echo "Clearing stuck Terminating namespaces..."
for ns in $(kubectl get ns --field-selector status.phase=Terminating \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    echo "  Force-finalizing $ns"
    kubectl get ns "$ns" -o json \
        | jq '.spec.finalizers = []' \
        | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - \
            >/dev/null 2>&1 || true
done

###############################################################################
# Phase 3d — Kyverno-specific cleanup (cluster-scoped webhooks, policies, CRDs)
###############################################################################
if contains "$DISABLED_FLUX" "kyverno"; then
    echo "Cleaning up Kyverno cluster-scoped resources..."
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration \
        -l app.kubernetes.io/instance=kyverno --ignore-not-found 2>/dev/null || true
    kubectl delete clusterpolicy --all --ignore-not-found 2>/dev/null || true
    kubectl delete clusterrole,clusterrolebinding \
        -l app.kubernetes.io/instance=kyverno --ignore-not-found 2>/dev/null || true
    for crd in $(kubectl get crd -o name 2>/dev/null | grep kyverno.io); do
        kubectl delete "$crd" --ignore-not-found --wait=false 2>/dev/null || true
    done
fi

###############################################################################
# Phase 3e — Azure cluster-scoped resource cleanup
###############################################################################
if contains "$DISABLED_RAW" "azure"; then
    echo "Cleaning up Azure cluster-scoped resources..."
    kubectl delete storageclass azure-disk azure-file \
        --ignore-not-found 2>/dev/null || true
fi

###############################################################################
# Phase 3f — Orphaned PV cleanup
###############################################################################
if [[ -n "$NAMESPACES" ]]; then
    echo "Cleaning up orphaned PVs..."
    for ns in $NAMESPACES; do
        for pv in $(kubectl get pv -o json 2>/dev/null \
            | jq -r '.items[] | select(.spec.claimRef.namespace=="'"$ns"'") | .metadata.name'); do
            echo "  Force-cleaning PV $pv (ns=$ns)"
            kubectl patch pv "$pv" --type=merge \
                -p '{"metadata":{"finalizers":null},"spec":{"claimRef":null}}' \
                2>/dev/null || true
            kubectl delete pv "$pv" --ignore-not-found --wait=false \
                2>/dev/null || true
        done
    done
fi

###############################################################################
# Phase 3g — Named cluster-scoped resources from raw apps
###############################################################################
cleanup_raw_app() {
    local app="$1"
    case "$app" in
        backstage)
            kubectl delete clusterrolebinding backstage-cluster-reader \
                --ignore-not-found 2>/dev/null || true
            ;;
        wazuh)
            kubectl delete clusterrole wazuh-filebeat \
                --ignore-not-found 2>/dev/null || true
            kubectl delete clusterrolebinding wazuh-filebeat \
                --ignore-not-found 2>/dev/null || true
            ;;
        velero)
            kubectl delete clusterrolebinding velero \
                --ignore-not-found 2>/dev/null || true
            kubectl delete crd -l component=velero \
                --ignore-not-found --wait=false 2>/dev/null || true
            for crd in $(kubectl get crd -o name 2>/dev/null | grep velero.io); do
                kubectl delete "$crd" --ignore-not-found --wait=false \
                    2>/dev/null || true
            done
            ;;
        knative)
            kubectl delete clusterrole knative-operator \
                --ignore-not-found 2>/dev/null || true
            kubectl delete clusterrolebinding knative-operator \
                --ignore-not-found 2>/dev/null || true
            for crd in $(kubectl get crd -o name 2>/dev/null | grep knative.dev); do
                kubectl delete "$crd" --ignore-not-found --wait=false \
                    2>/dev/null || true
            done
            ;;
        kubevirt)
            kubectl delete clusterrole,clusterrolebinding -l kubevirt.io \
                --ignore-not-found 2>/dev/null || true
            kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration \
                -l kubevirt.io --ignore-not-found 2>/dev/null || true
            kubectl delete apiservice -l kubevirt.io \
                --ignore-not-found 2>/dev/null || true
            for crd in $(kubectl get crd -o name 2>/dev/null | grep kubevirt.io); do
                kubectl delete "$crd" --ignore-not-found --wait=false \
                    2>/dev/null || true
            done
            ;;
    esac
}

if [[ -n "$DISABLED_RAW" ]]; then
    echo "Cleaning up cluster-scoped resources from raw apps..."
    for app in $DISABLED_RAW; do
        cleanup_raw_app "$app"
    done
fi

###############################################################################
# Phase 3h — Label-based cleanup for Flux HelmRelease apps
###############################################################################

# Get the Helm instance label for a flux app (empty if not mapped)
flux_helm_label() {
    case "$1" in
        cert-manager)    echo "app.kubernetes.io/instance=cert-manager" ;;
        keda)            echo "app.kubernetes.io/instance=keda" ;;
        falco)           echo "app.kubernetes.io/instance=falco" ;;
        trivy)           echo "app.kubernetes.io/instance=trivy-operator" ;;
        dapr)            echo "app.kubernetes.io/part-of=dapr" ;;
        argocd)          echo "app.kubernetes.io/instance=argocd" ;;
        argo-workflows)  echo "app.kubernetes.io/instance=argo-workflows" ;;
        1pass)           echo "app.kubernetes.io/instance=connect" ;;
        *)               echo "" ;;
    esac
}

# Get the CRD grep pattern for a flux app (empty if not mapped)
flux_crd_pattern() {
    case "$1" in
        cert-manager)    echo "cert-manager.io" ;;
        keda)            echo "keda.sh" ;;
        dapr)            echo "dapr.io" ;;
        argocd)          echo "argoproj.io" ;;
        argo-workflows)  echo "argoproj.io" ;;
        trivy)           echo "aquasecurity.github.io" ;;
        1pass)           echo "onepassword.com" ;;
        *)               echo "" ;;
    esac
}

if [[ -n "$DISABLED_FLUX" ]]; then
    for app in $DISABLED_FLUX; do
        label="$(flux_helm_label "$app")"
        if [[ -n "$label" ]]; then
            echo "  Cleaning cluster-scoped resources for $app..."
            kubectl delete clusterrole,clusterrolebinding -l "$label" \
                --ignore-not-found 2>/dev/null || true
            kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration \
                -l "$label" --ignore-not-found 2>/dev/null || true
            kubectl delete crd -l "$label" \
                --ignore-not-found --wait=false 2>/dev/null || true
        fi

        pattern="$(flux_crd_pattern "$app")"
        if [[ -n "$pattern" ]]; then
            for crd in $(kubectl get crd -o name 2>/dev/null | grep "$pattern"); do
                kubectl delete "$crd" --ignore-not-found --wait=false \
                    2>/dev/null || true
            done
        fi
    done
fi

###############################################################################
# Phase 3i — Force-clear stuck CRD finalizers
###############################################################################
echo "Clearing stuck CRD finalizers..."
for crd in $(kubectl get crd -o json 2>/dev/null \
    | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name'); do
    echo "  Force-finalizing CRD $crd"
    kubectl patch crd "$crd" --type=merge \
        -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
done

echo "✓ Cleanup complete"
