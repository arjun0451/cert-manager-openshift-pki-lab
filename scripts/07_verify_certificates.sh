#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
need openssl
for spec in "caller-app-tls:$CALLER_NAMESPACE:caller-app-tls-secret" "calling-app-tls:$CALLING_NAMESPACE:calling-app-tls-secret"; do
  IFS=: read -r cert ns secret <<< "$spec"; echo "Waiting for $cert in $ns"
  ready=false
  for i in {1..90}; do
    if [[ "$(oc get certificate "$cert" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)" == True ]]; then ready=true; break; fi
    sleep 2
  done
  [[ "$ready" == true ]] || { oc describe certificate "$cert" -n "$ns"; exit 1; }
  oc get secret "$secret" -n "$ns" >/dev/null
  certfile="$(mktemp)"
  oc get secret "$secret" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$certfile"
  eku="$(openssl x509 -in "$certfile" -noout -ext extendedKeyUsage)"
  rm -f "$certfile"
  grep -q 'TLS Web Server Authentication' <<< "$eku" || { echo "Missing serverAuth EKU in $secret" >&2; exit 1; }
  grep -q 'TLS Web Client Authentication' <<< "$eku" || { echo "Missing clientAuth EKU in $secret" >&2; exit 1; }
  echo "  Ready with serverAuth + clientAuth: $secret"
done
