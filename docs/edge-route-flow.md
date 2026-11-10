# Edge Route TLS Flow

`make edge-route` deploys `nginx-edge-app` in `edgeroute-ns`. It reuses the lab NGINX image and resource profile but exposes HTTP only on port 8080.

The scenario creates `edge-route-cert` through `external-intermediate-ca`. The Certificate SAN is `nginx-edge-route.<apps-domain>` and its Secret is `edge-route-tls`.

```text
External client -- HTTPS --> OpenShift router -- HTTP --> nginx-edge-service --> NGINX
```

The Route uses `route.openshift.io/v1`, `termination: edge`, `insecureEdgeTerminationPolicy: Redirect`, and `spec.tls.externalCertificate.name: edge-route-tls`. Scoped RBAC allows the router service account to read only that Secret. cert-manager renewals update the Secret; the Route continues to reference it without storing a private key in Git or the Route manifest.

## Commands

```bash
make edge-route
make verify-edge-route
CLEANUP_DRY_RUN=true make clean-edge-route
```

Verification confirms Certificate readiness, Route configuration, the external certificate SAN, HTTPS access, and the page statement that the backend observed HTTP. This scenario intentionally does not demonstrate end-to-end TLS.
