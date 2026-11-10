#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
need openssl
validate_config
domain=''
[[ "$INCLUDE_ROUTE_SANS" == true ]] && domain="$(resolve_apps_domain)"
for spec in "$CALLER_CERTIFICATE_NAME:$CALLER_NAMESPACE:$CALLER_SECRET_NAME:$CALLER_APP_NAME" "$CALLING_CERTIFICATE_NAME:$CALLING_NAMESPACE:$CALLING_SECRET_NAME:$CALLING_APP_NAME"; do
  IFS=: read -r cert ns secret app_name <<< "$spec"; echo "Waiting for $cert in $ns"
  ready=false
  for i in {1..90}; do
    if [[ "$(oc get certificate "$cert" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)" == True ]]; then ready=true; break; fi
    sleep 2
  done
  [[ "$ready" == true ]] || { oc describe certificate "$cert" -n "$ns"; exit 1; }
  oc get secret "$secret" -n "$ns" >/dev/null
  [[ "$(oc get certificate "$cert" -n "$ns" -o jsonpath='{.spec.duration}')" == "$CERTIFICATE_DURATION" ]] || { echo "Unexpected duration in $cert" >&2; exit 1; }
  [[ "$(oc get certificate "$cert" -n "$ns" -o jsonpath='{.spec.renewBefore}')" == "$CERTIFICATE_RENEW_BEFORE" ]] || { echo "Unexpected renewBefore in $cert" >&2; exit 1; }
  [[ -n "$(oc get certificate "$cert" -n "$ns" -o jsonpath='{.status.renewalTime}')" ]] || { echo "Missing renewalTime in $cert" >&2; exit 1; }
  certfile="$(mktemp)"
  oc get secret "$secret" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$certfile"
  eku="$(openssl x509 -in "$certfile" -noout -ext extendedKeyUsage)"
  sans="$(openssl x509 -in "$certfile" -noout -ext subjectAltName)"
  rm -f "$certfile"
  grep -q 'TLS Web Server Authentication' <<< "$eku" || { echo "Missing serverAuth EKU in $secret" >&2; exit 1; }
  grep -q 'TLS Web Client Authentication' <<< "$eku" || { echo "Missing clientAuth EKU in $secret" >&2; exit 1; }
  for san in "$app_name" "$app_name.$ns" "$app_name.$ns.svc" "$app_name.$ns.svc.cluster.local"; do
    grep -Fq "DNS:$san" <<< "$sans" || { echo "Missing DNS SAN $san in $secret" >&2; exit 1; }
  done
  if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
    grep -Fq "DNS:$app_name.$domain" <<< "$sans" || { echo "Missing Route DNS SAN in $secret" >&2; exit 1; }
  fi
  echo "  Ready with serverAuth + clientAuth: $secret"
done
