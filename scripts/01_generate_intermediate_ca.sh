#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
need openssl
ROOT="$PROJECT_DIR/certs/root"; INT="$PROJECT_DIR/certs/intermediate"
[[ -s "$ROOT/certs/ca.cert.pem" && -s "$ROOT/private/ca-key.pem" ]] || { echo 'Generate Root CA first.' >&2; exit 1; }
mkdir -p "$INT/private" "$INT/certs" "$INT/csr"; chmod 700 "$INT/private"
if [[ -s "$INT/certs/intermediate.cert.pem" ]]; then echo 'Intermediate CA already exists; leaving it unchanged.'; exit 0; fi
openssl genrsa -out "$INT/private/intermediate.key.pem" 4096
chmod 600 "$INT/private/intermediate.key.pem"
openssl req -new -sha256 -key "$INT/private/intermediate.key.pem" -out "$INT/csr/intermediate.csr"   -subj "/C=US/O=Lab PKI/OU=Issuing CA/CN=${INTERMEDIATE_CA_COMMON_NAME:-Acme Intermediate CA}"
openssl x509 -req -in "$INT/csr/intermediate.csr" -CA "$ROOT/certs/ca.cert.pem" -CAkey "$ROOT/private/ca-key.pem"   -CAcreateserial -out "$INT/certs/intermediate.cert.pem" -days 1825 -sha256 -extfile "$PROJECT_DIR/openssl/intermediate-v3.ext"
openssl verify -CAfile "$ROOT/certs/ca.cert.pem" "$INT/certs/intermediate.cert.pem"
