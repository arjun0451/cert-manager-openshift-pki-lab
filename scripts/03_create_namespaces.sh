#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
for ns in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE"; do
  if ! oc get namespace "$ns" >/dev/null 2>&1; then
    oc create namespace "$ns"
    oc label namespace "$ns" pki-lab-created=true --overwrite
  fi
  oc label namespace "$ns" pki-lab-managed=true --overwrite
done
