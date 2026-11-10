# trust-manager mTLS Scenario

Before the first run, enable the OpenShift cert-manager Operator Technology Preview feature with `UNSUPPORTED_ADDON_FEATURES=TrustManager=true` on its Subscription. Then `make trust-manager` creates the singleton cluster-scoped trust-manager operand. It is deliberately separate from scenario cleanup because it can serve workloads beyond this lab. `make trustbundle-mtls` creates `trust-caller-ns` and `trust-calling-ns`, then deploys two NGINX applications that communicate with mutual TLS. This scenario is separate from the existing caller/calling and edge Route labs.

The cluster-scoped `Bundle` named `pki-lab-java-trust-bundle` reads the Intermediate and Root CA certificates from `ca-key-pair` in the configured trust-manager namespace. It writes a ConfigMap of the same name into only namespaces labelled `pki-lab-trust-scenario=true`.

The ConfigMap contains:

- `ca-bundle.crt` — PEM trust bundle used by NGINX.
- `ca-bundle.p12` — passwordless Java-compatible PKCS#12 truststore, using the `Modern2023` profile.

Both files contain public CA certificates only. NGINX mounts both files but uses the PEM key for its mTLS trust setting; the PKCS#12 file is available for applications that need it.

When `CREATE_ROUTES=true`, each application receives a passthrough Route at `<application>.<apps-domain>`. Set `INCLUDE_ROUTE_SANS=true` so the issued leaf certificates include those Route hostnames.

`TRUST_MANAGER_NAMESPACE` must match the trust-manager controller's configured trust namespace and contain the lab's `ca-key-pair` Secret. Run `make verify-trustbundle-mtls` to validate Bundle synchronization, inspect the PKCS#12 truststore, and test mTLS in both directions. Use `CLEANUP_DRY_RUN=true make clean-trustbundle-mtls` to preview removal.
