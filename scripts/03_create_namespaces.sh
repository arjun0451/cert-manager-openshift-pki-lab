#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
validate_config
for ns in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE"; do
  if ! oc get namespace "$ns" >/dev/null 2>&1; then
    oc create namespace "$ns"
    oc label namespace "$ns" pki-lab-created=true pki-lab-owned=true --overwrite
  fi
done
