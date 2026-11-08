# Test Cases

## Certificate issuance

```bash
oc get clusterissuer external-intermediate-ca
oc get certificate -n caller-ns caller-app-tls
oc get certificate -n calling-ns calling-app-tls
```

Expected: ClusterIssuer Ready=True and both Certificates Ready=True. Inspect EKUs and SANs:

```bash
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -ext extendedKeyUsage -ext subjectAltName
```

## Bidirectional mTLS

```bash
make verify-mtls
```

Expected: the caller curl pod presents caller identity to caller NGINX, which presents that same identity to calling NGINX; the reverse path uses the calling identity. An unauthenticated request to the caller TLS listener fails. Trust and hostname validation are enabled; tests must not use `-k`.

## Route hostname discovery

```bash
oc get ingress.config/cluster -o jsonpath='{.spec.domain}{"\n"}'
oc get route caller-app -n caller-ns -o jsonpath='{.spec.host}{"\n"}'
```

The Route host should use the current cluster apps domain. The corresponding hostname is included in the leaf certificate when `INCLUDE_ROUTE_SANS=true`.

## Renewal

```bash
oc describe certificate caller-app-tls -n caller-ns
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial -dates
```

Validate how the deployed NGINX image reloads updated mounted Secret files. Restart the deployment after renewal if automatic reload is not configured.
