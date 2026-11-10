# Validation Cases

## Offline configuration and rendering

```bash
make test
make render
make validate
```

Expected: configuration precedence works, wildcard apps domains are normalized, all generated YAML is placeholder-free, Route API versions/termination settings are valid, and certificate SAN/EKU templates are present. These checks do not contact OpenShift.

## Base certificate issuance and mTLS

```bash
make verify-pki
make verify-certs
make verify-mtls
```

Expected: `external-intermediate-ca` and both base Certificates are Ready. Each leaf has service DNS SANs plus `serverAuth` and `clientAuth`. Verification performs authenticated mTLS in both directions and browser-compatible HTTPS without a client certificate. It does not use `curl -k`.

## Edge Route

```bash
make edge-route
make verify-edge-route
```

Expected: `edge-route-cert` has the Route hostname SAN, the Route uses edge termination and `externalCertificate`, and the page confirms HTTP between the router and backend.

## trust-manager bundle and Routes

```bash
make trustbundle-mtls
make verify-trustbundle-mtls
```

Expected: the Bundle condition is `Synced=True`; both selected namespaces contain `ca-bundle.crt` and `ca-bundle.p12`; both trust applications complete mTLS in each direction; and their passthrough Routes validate with the configured apps domain.

## Renewal

Operators may set short lab values such as `CERTIFICATE_DURATION=60m` and `CERTIFICATE_RENEW_BEFORE=10m`. After issuance, certificate renewal updates the Secret. NGINX must be restarted or otherwise reloaded before it serves the renewed certificate.
