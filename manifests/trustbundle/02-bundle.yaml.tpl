apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: __TRUST_BUNDLE_NAME__
  labels:
    app: pki-lab
    component: trust-bundle
    pki-lab-owned: "true"
spec:
  sources:
  - secret:
      name: ca-key-pair
      key: tls.crt
  - secret:
      name: ca-key-pair
      key: ca.crt
  target:
    configMap:
      key: ca-bundle.crt
      metadata:
        labels:
          app: pki-lab
          component: trust-bundle
          pki-lab-owned: "true"
    additionalFormats:
      pkcs12:
        key: ca-bundle.p12
        profile: Modern2023
    namespaceSelector:
      matchLabels:
        pki-lab-trust-scenario: "true"
