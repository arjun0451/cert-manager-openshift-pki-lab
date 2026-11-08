# Troubleshooting

## ClusterIssuer is not Ready

```bash
oc describe clusterissuer external-intermediate-ca
oc get secret ca-key-pair -n cert-manager
oc get events -n cert-manager --sort-by=.lastTimestamp
```

Confirm the Secret contains `tls.crt` (Intermediate certificate), `tls.key` (matching Intermediate key), and `ca.crt` (public Root certificate). The Root certificate is not the signing certificate.

## Certificate is not Ready

```bash
oc describe certificate caller-app-tls -n caller-ns
oc describe certificaterequest -n caller-ns
oc get events -n caller-ns --sort-by=.lastTimestamp
```

Check issuer readiness, SAN rendering, and that the apps domain can be discovered. Set `APPS_DOMAIN` in `config/lab.env` only if API discovery is unavailable.

## TLS hostname or trust failure

Confirm the certificate contains the exact service DNS/Route hostname and both Root and Intermediate certificates are in `pki-trust-bundle`:

```bash
oc get configmap pki-trust-bundle -n caller-ns -o yaml
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

Do not disable verification with `curl -k`; fix the trust bundle or SAN instead.

## mTLS handshake failure

```bash
oc logs deployment/nginx-caller -n caller-ns
oc logs deployment/nginx-calling -n calling-ns
oc exec deployment/nginx-caller -n caller-ns -- nginx -t
```

Ensure each app mounts its own `*-tls-secret` at `/etc/nginx/certs`, the public CA bundle at `/etc/nginx/trust/ca-bundle.crt`, and that the peer cert has `clientAuth` EKU. Ensure both Routes are passthrough if external TLS is being tested.

## Disconnected cluster

Mirror `curlimages/curl:8.10.1` into the internal registry and update the image in `scripts/10_verify_mtls.sh` before running the verification target.
