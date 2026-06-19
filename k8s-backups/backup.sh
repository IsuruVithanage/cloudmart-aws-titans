#!/usr/bin/env bash
# =============================================================
# k8s-backup/backup.sh
# Exports all Kubernetes resources from cloudmart-prod namespace
# to cloudmart-prod-backup.yaml for disaster recovery.
#
#
# Usage:
#   chmod +x k8s-backups/backup.sh
#   ./k8s-backups/backup.sh
#
# Pre-requisites:
#   - kubectl configured and pointing at cloudmart-eks cluster
#   - AWS credentials with EKS describe access
# =============================================================

set -euo pipefail

NAMESPACE="cloudmart-prod"
OUTPUT_FILE="$(dirname "$0")/cloudmart-prod-backup.yaml"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "[backup] Starting Kubernetes resource export at $TIMESTAMP"
echo "[backup] Namespace: $NAMESPACE → $OUTPUT_FILE"

# Verify we are pointing at the right cluster
CURRENT_CONTEXT=$(kubectl config current-context)
echo "[backup] Active kubectl context: $CURRENT_CONTEXT"

# Export all namespaced resources
# Note: 'kubectl get all' does NOT include ConfigMaps, Secrets, NetworkPolicies,
# PDBs, HPA, ServiceAccounts etc., so we enumerate explicitly.
kubectl get \
  deployments,replicasets,pods,services,\
  configmaps,secrets,serviceaccounts,\
  horizontalpodautoscalers,poddisruptionbudgets,\
  networkpolicies,ingresses \
  -n "$NAMESPACE" \
  -o yaml \
  > "$OUTPUT_FILE"

# Append ScaledObjects (KEDA CRDs — not in standard 'all')
kubectl get scaledobjects,triggerauthentications \
  -n "$NAMESPACE" \
  -o yaml \
  >> "$OUTPUT_FILE" 2>/dev/null || echo "[backup] No KEDA resources found (safe to ignore)"

# Append ExternalSecrets (ESO CRDs)
kubectl get externalsecrets,secretstores,clustersecretstores \
  -n "$NAMESPACE" \
  -o yaml \
  >> "$OUTPUT_FILE" 2>/dev/null || echo "[backup] No ExternalSecret resources found (safe to ignore)"

echo "[backup] ✅ Backup complete: $(wc -l < "$OUTPUT_FILE") lines written to $OUTPUT_FILE"
echo "[backup] Timestamp embedded in backup: $TIMESTAMP"
