#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${PROJECT_DIR}/config/lab.env"
[[ -f "$CONFIG_FILE" ]] || CONFIG_FILE="${PROJECT_DIR}/config/lab.env.example"
# shellcheck disable=SC1090
source "$CONFIG_FILE"
CALLER_NAMESPACE="${CALLER_NAMESPACE:-caller-ns}"
CALLING_NAMESPACE="${CALLING_NAMESPACE:-calling-ns}"
CERT_MANAGER_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-external-intermediate-ca}"
INCLUDE_ROUTE_SANS="${INCLUDE_ROUTE_SANS:-true}"
APPS_DOMAIN="${APPS_DOMAIN:-}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: Required command '$1' not found" >&2; exit 1; }; }
require_oc_login() { need oc; oc whoami >/dev/null 2>&1 || { echo 'ERROR: Run oc login first.' >&2; exit 1; }; }
discover_domain() {
  if [[ -z "$APPS_DOMAIN" ]]; then
    APPS_DOMAIN="$(oc get ingress.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
  fi
  [[ -n "$APPS_DOMAIN" ]] || { echo 'ERROR: Could not discover OpenShift apps domain. Set APPS_DOMAIN in config/lab.env.' >&2; exit 1; }
  printf '%s' "$APPS_DOMAIN"
}
