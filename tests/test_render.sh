#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
render() {
  local output="$1"; shift
  RENDER_DIR="$output" "$@" "$PROJECT_DIR/scripts/render_manifests.sh" >/dev/null
}

first="$(mktemp -d)"; second="$(mktemp -d)"; third="$(mktemp -d)"
trap 'rm -rf "$first" "$second" "$third"' EXIT

render "$first" env CALLER_NAMESPACE=alpha CALLING_NAMESPACE=beta CALLER_APP_NAME=frontend CALLING_APP_NAME=backend APPS_DOMAIN='*.apps.example.com' CREATE_ROUTES=true INCLUDE_ROUTE_SANS=true CERTIFICATE_DURATION=2h CERTIFICATE_RENEW_BEFORE=10m
grep -q 'https://backend.beta.svc.cluster.local:443/' "$first/caller-01-configmap.yaml"
grep -q 'ssl_verify_client optional' "$first/caller-01-configmap.yaml"
grep -q 'Calling backend succeeded' "$first/caller-01-configmap.yaml"
grep -q 'host: frontend.apps.example.com' "$first/caller-route.yaml"
grep -q -- '- frontend.apps.example.com' "$first/caller-certificate.yaml"
grep -q 'duration: 2h' "$first/caller-certificate.yaml"
grep -q 'renewBefore: 10m' "$first/caller-certificate.yaml"
grep -q 'host: nginx-edge-route.apps.example.com' "$first/edgeroute-07-route.yaml"
grep -q 'termination: edge' "$first/edgeroute-07-route.yaml"
grep -q 'insecureEdgeTerminationPolicy: Redirect' "$first/edgeroute-07-route.yaml"
grep -q 'externalCertificate:' "$first/edgeroute-07-route.yaml"
grep -q 'duration: 2h' "$first/edgeroute-04-certificate.yaml"
grep -q 'renewBefore: 10m' "$first/edgeroute-04-certificate.yaml"
grep -q 'Backend transport seen by this pod: <strong>\$scheme</strong>' "$first/edgeroute-01-configmap.yaml"
grep -q 'kind: Bundle' "$first/trustbundle-bundle.yaml"
grep -q 'key: ca-bundle.p12' "$first/trustbundle-bundle.yaml"
grep -q 'profile: Modern2023' "$first/trustbundle-bundle.yaml"
grep -q 'name: trust-caller-app' "$first/trustbundle-caller-service.yaml"
grep -q 'name: trust-calling-app' "$first/trustbundle-calling-service.yaml"
grep -q 'key: ca-bundle.p12' "$first/trustbundle-caller-deployment.yaml"

render "$second" env APPS_DOMAIN= CREATE_ROUTES=false INCLUDE_ROUTE_SANS=true APPS_DOMAIN_FALLBACK=local.apps.example.test
[[ ! -e "$second/caller-route.yaml" ]]
grep -q -- '- caller-app.local.apps.example.test' "$second/caller-certificate.yaml"

render "$third" env APPS_DOMAIN=apps.example.com CREATE_ROUTES=true INCLUDE_ROUTE_SANS=false
[[ -e "$third/caller-route.yaml" ]]
! grep -q -- '- caller-app.apps.example.com' "$third/caller-certificate.yaml"
! grep -R -q '__[A-Z0-9_]+__' "$first" "$second" "$third"
