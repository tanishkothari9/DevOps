#!/usr/bin/env bash
# ==============================================================================
# Script: load_generator.sh
# Purpose: Start / stop in-cluster traffic against yatri-backend-service to trigger
#          HPA scaling. Adapted from the instructor's load_generator.sh (which used
#          curl + port-forward from the laptop) so the load is spread across all Pods.
# Usage:   ./load_generator.sh start [workers]   (default 3 workers)
#          ./load_generator.sh stop
# ==============================================================================
set -euo pipefail

NAMESPACE="s13-hpa-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-start}"
WORKERS="${2:-3}"

case "$ACTION" in
  start)
    echo "Starting $WORKERS load-generator workers against http://yatri-backend-service ..."
    kubectl apply -f "$SCRIPT_DIR/load-generator.yaml"
    kubectl scale deployment/load-generator -n "$NAMESPACE" --replicas="$WORKERS"
    echo "Load active. Watch it with: kubectl get hpa -n $NAMESPACE -w"
    ;;
  stop)
    echo "Stopping load generator..."
    kubectl delete -f "$SCRIPT_DIR/load-generator.yaml" --ignore-not-found
    ;;
  *)
    echo "Usage: $0 {start [workers]|stop}" >&2
    exit 1
    ;;
esac
