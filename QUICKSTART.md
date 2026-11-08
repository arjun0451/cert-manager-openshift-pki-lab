# Quick Start

1. Confirm OpenShift login and cert-manager installation:

   ```bash
   oc whoami
   oc get crd certificates.cert-manager.io clusterissuers.cert-manager.io
   oc get namespace cert-manager
   ```

2. Optional configuration:

   ```bash
   cp config/lab.env.example config/lab.env
   # APPS_DOMAIN can remain empty; it is discovered from the cluster.
   ```

3. Bootstrap everything:

   ```bash
   make bootstrap
   ```

4. Check status:

   ```bash
   oc get clusterissuer external-intermediate-ca
   oc get certificates -n caller-ns
   oc get certificates -n calling-ns
   oc get pods -n caller-ns
   oc get pods -n calling-ns
   ```

5. Run bidirectional mTLS positive and unauthenticated negative tests:

   ```bash
   make verify-mtls
   ```

The setup creates one leaf cert per app. Each cert is dual-purpose (`serverAuth` + `clientAuth`) and reused by that app for inbound and outbound TLS. The Root private key remains local/offline. See [README](README.md) for design, configuration and cleanup details.
