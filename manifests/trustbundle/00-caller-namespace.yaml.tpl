apiVersion: v1
kind: Namespace
metadata:
  name: __TRUST_CALLER_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    pki-lab-created: "true"
    pki-lab-trust-scenario: "true"
