# Architecture

## Base mTLS

```text
caller-app -- mTLS over Service DNS --> calling-app
calling-app -- mTLS over Service DNS --> caller-app
```

The offline Root CA signs the Intermediate CA. cert-manager uses the Intermediate keypair in `ca-key-pair` to issue the two base leaf certificates. Each leaf certificate includes service DNS SANs and both `serverAuth` and `clientAuth` EKUs. The application holding a leaf keypair uses it for server TLS and client TLS.

Both workloads mount their own TLS Secret and a separate public Root-plus-Intermediate ConfigMap. NGINX uses the PEM trust bundle for client-certificate verification and upstream hostname verification. Port 8080 serves only health probes; port 8443 serves HTTPS. Client certificates are optional for browser-facing HTTPS, but required by the NGINX upstream mTLS configuration.

## Route models

The base and trust-manager scenarios use passthrough Routes. TLS reaches NGINX, and the Route hostname must be present in the leaf certificate when `INCLUDE_ROUTE_SANS=true`.

The edge scenario uses a different flow:

```text
External client -- HTTPS --> OpenShift router -- HTTP --> Service --> NGINX pod
```

The router reads the cert-manager Secret through scoped RBAC and terminates TLS. The edge pod has no serving TLS configuration.

## trust-manager scenario

The cluster-scoped `Bundle` reads the Intermediate and Root public certificates from the configured trust namespace. It creates a selected-namespace ConfigMap containing `ca-bundle.crt` and `ca-bundle.p12`. The two trust-manager scenario applications use the PEM file for NGINX mTLS and mount the PKCS#12 file for Java-compatible consumers.
