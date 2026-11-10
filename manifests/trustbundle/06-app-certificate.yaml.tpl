apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: __TRUST_APP_NAME__-tls
  namespace: __TRUST_NAMESPACE__
  labels:
    app: pki-lab
    component: trust-mtls
    pki-lab-owned: "true"
spec:
  secretName: __TRUST_SECRET_NAME__
  duration: __CERTIFICATE_DURATION__
  renewBefore: __CERTIFICATE_RENEW_BEFORE__
  dnsNames:
  - __TRUST_APP_NAME__
  - __TRUST_APP_NAME__.__TRUST_NAMESPACE__
  - __TRUST_APP_NAME__.__TRUST_NAMESPACE__.svc
  - __TRUST_APP_NAME__.__TRUST_NAMESPACE__.svc.cluster.local
  usages: [digital signature, key encipherment, server auth, client auth]
  privateKey: {algorithm: RSA, size: 2048, rotationPolicy: Always}
  issuerRef:
    name: __CLUSTER_ISSUER_NAME__
    kind: ClusterIssuer
    group: cert-manager.io
