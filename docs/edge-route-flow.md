# Edge Route TLS Flow

`make edge-route` deploys an HTTP-only NGINX backend in `edgeroute-ns` using the existing lab NGINX image and resource profile. cert-manager issues `edge-route-tls` for `nginx-edge-route.<apps-domain>` through `external-intermediate-ca`.

The Route uses edge termination and `spec.tls.externalCertificate` to reference that Secret. The OpenShift router reads the Secret through a narrowly scoped Role and RoleBinding, so cert-manager renewal updates are consumed without copying private key material into Git or the Route specification.

```text
External client -- HTTPS --> OpenShift router -- HTTP --> Service --> NGINX pod
```

The page returned through the Route reports `Backend transport seen by this pod: http`, demonstrating that TLS terminates at the router. This scenario is not end-to-end encryption.

Use `make verify-edge-route` to verify the certificate SAN, Route configuration, external HTTPS, and HTTP backend transport. Use `CLEANUP_DRY_RUN=true make clean-edge-route` to preview cleanup, or `make clean-edge-route` to remove only a namespace the lab created and labelled.
