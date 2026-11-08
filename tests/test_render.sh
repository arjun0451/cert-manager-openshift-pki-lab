#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
render() {
  local output="$1"; shift
  RENDER_DIR="$output" "$@" "$PROJECT_DIR/scripts/render_manifests.sh" >/dev/null
}

first="$(mktemp -d)"; second="$(mktemp -d)"; third="$(mktemp -d)"
trap 'rm -rf "$first" "$second" "$third"' EXIT

render "$first" env CALLER_NAMESPACE=alpha CALLING_NAMESPACE=beta CALLER_APP_NAME=frontend CALLING_APP_NAME=backend APPS_DOMAIN='*.apps.example.com' CREATE_ROUTES=true INCLUDE_ROUTE_SANS=true
rg -q 'https://backend.beta.svc.cluster.local:443/' "$first/caller-01-configmap.yaml"
rg -q 'host: frontend.apps.example.com' "$first/caller-route.yaml"
rg -q -- '- frontend.apps.example.com' "$first/caller-certificate.yaml"

render "$second" env APPS_DOMAIN= CREATE_ROUTES=false INCLUDE_ROUTE_SANS=true APPS_DOMAIN_FALLBACK=local.apps.example.test
[[ ! -e "$second/caller-route.yaml" ]]
rg -q -- '- caller-app.local.apps.example.test' "$second/caller-certificate.yaml"

render "$third" env APPS_DOMAIN=apps.example.com CREATE_ROUTES=true INCLUDE_ROUTE_SANS=false
[[ -e "$third/caller-route.yaml" ]]
! rg -q -- '- caller-app.apps.example.com' "$third/caller-certificate.yaml"
! rg -q '__[A-Z0-9_]+__' "$first" "$second" "$third"
