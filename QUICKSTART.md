# Quick Start

This guide deploys the base bidirectional mTLS scenario. It does not enable the optional edge Route or trust-manager scenarios.

## 1. Prepare local configuration

```bash
cp config/lab.env.example config/lab.env
make test
make validate
```

`config/lab.env` is local-only. Operators should set `APPS_DOMAIN` when the cluster domain must be explicit; otherwise the deployment resolves it from OpenShift. Environment variables override the local file.

## 2. Confirm cluster access

```bash
oc whoami
oc get crd certificates.cert-manager.io clusterissuers.cert-manager.io
make prereqs
```

The selected cert-manager namespace must already exist. The logged-in identity requires permission to create namespaces, Secrets, ConfigMaps, Certificates, Deployments, Services, Routes, and the lab ClusterIssuer.

## 3. Deploy and verify base mTLS

```bash
make bootstrap
make verify-pki
make verify-certs
make verify-mtls
```

The bootstrap workflow creates local Root and Intermediate CA material only when it is absent. It then deploys the caller and calling applications. The verification command tests authenticated service-to-service traffic in both directions and browser-compatible HTTPS access without a client certificate.

## 4. Use optional scenarios

```bash
# Router edge TLS termination; backend remains HTTP.
make edge-route
make verify-edge-route

# Requires enabled trust-manager feature and a TrustManager operand.
make trust-manager
make trustbundle-mtls
make verify-trustbundle-mtls
```

## 5. Preview cleanup

```bash
CLEANUP_DRY_RUN=true make clean
CLEANUP_DRY_RUN=true make clean-edge-route
CLEANUP_DRY_RUN=true make clean-trustbundle-mtls
```

Cleanup removes only resources carrying the lab ownership labels. It does not remove pre-existing namespaces, local Root/Intermediate CA files, or the shared cluster-scoped TrustManager operand.
