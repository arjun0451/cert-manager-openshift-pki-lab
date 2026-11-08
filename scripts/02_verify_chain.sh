#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
need openssl
ROOT="$PROJECT_DIR/certs/root/certs/ca.cert.pem"; INT="$PROJECT_DIR/certs/intermediate/certs/intermediate.cert.pem"
[[ -s "$ROOT" && -s "$INT" ]] || { echo 'Root or Intermediate CA missing.' >&2; exit 1; }
openssl verify -CAfile "$ROOT" "$INT"
openssl x509 -in "$INT" -noout -text | grep -A2 'Basic Constraints'
