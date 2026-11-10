# trust-manager mTLS Scenario

This optional scenario demonstrates OpenShift trust-manager distribution of a PEM trust bundle and a Java-compatible PKCS#12 truststore. It is separate from the base and edge scenarios.

## Prerequisite

trust-manager is a cluster-scoped Technology Preview operand. An administrator first enables `UNSUPPORTED_ADDON_FEATURES=TrustManager=true` on the cert-manager Operator Subscription, then creates the singleton operand:

```bash
oc -n cert-manager-operator patch subscription openshift-cert-manager-operator \
  --type='merge' \
  -p '{"spec":{"config":{"env":[{"name":"UNSUPPORTED_ADDON_FEATURES","value":"TrustManager=true"}]}}}'
make trust-manager
oc wait --for=condition=Ready trustmanager/cluster --timeout=180s
```

`TRUST_MANAGER_NAMESPACE` must match the operand trust namespace and contain the lab `ca-key-pair` Secret. The default is `cert-manager`.

## Deployment

```bash
make trustbundle-mtls
make verify-trustbundle-mtls
```

The Bundle selects only namespaces labelled `pki-lab-trust-scenario=true`. It publishes `pki-lab-java-trust-bundle` with:

- `ca-bundle.crt`: Intermediate plus Root PEM certificates, used by NGINX.
- `ca-bundle.p12`: passwordless PKCS#12 truststore using the `Modern2023` profile, available to Java-compatible applications.

Neither bundle file contains a private key. The two NGINX workloads use the PEM file for mutual TLS and mount the PKCS#12 file as a demonstration artifact. When `CREATE_ROUTES=true`, both applications receive passthrough Routes; `INCLUDE_ROUTE_SANS=true` ensures the external Route hosts are certificate SANs.

## Cleanup

```bash
CLEANUP_DRY_RUN=true make clean-trustbundle-mtls
make clean-trustbundle-mtls
```

Scenario cleanup removes the Bundle and only namespaces created by the lab. It does not remove the shared `TrustManager` operand.
