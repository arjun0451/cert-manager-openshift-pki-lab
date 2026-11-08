#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
need openssl
D="$PROJECT_DIR/certs/root"; mkdir -p "$D/private" "$D/certs" "$D/csr"; chmod 700 "$D/private"
if [[ -s "$D/certs/ca.cert.pem" ]]; then echo 'Root CA already exists; leaving it unchanged.'; exit 0; fi
openssl genrsa -out "$D/private/ca-key.pem" 4096
chmod 600 "$D/private/ca-key.pem"
openssl req -x509 -new -sha256 -days 3650 -key "$D/private/ca-key.pem"   -out "$D/certs/ca.cert.pem" -subj "/C=US/O=Lab PKI/OU=Offline Security/CN=${ROOT_CA_COMMON_NAME:-Acme Root CA}"   -extensions v3_ca -config "$PROJECT_DIR/openssl/root-openssl.cnf"
openssl x509 -in "$D/certs/ca.cert.pem" -noout -subject -issuer -dates
printf '\nIMPORTANT: Root CA private key stays offline and is never imported into Kubernetes.\n'
