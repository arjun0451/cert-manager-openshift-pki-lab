apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: __APP_NAME__-tls
  namespace: __NAMESPACE__
  labels:
    app: pki-lab
    pki-lab-owned: "true"
spec:
  secretName: __SECRET_NAME__
  commonName: __APP_NAME__
  duration: __CERTIFICATE_DURATION__
  renewBefore: __CERTIFICATE_RENEW_BEFORE__
  dnsNames:
    - __APP_NAME__
    - __APP_NAME__.__NAMESPACE__
    - __APP_NAME__.__NAMESPACE__.svc
    - __APP_NAME__.__NAMESPACE__.svc.cluster.local
__ROUTE_SAN__
  usages:
    - digital signature
    - key encipherment
    - server auth
    - client auth
  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always
  issuerRef:
    name: __CLUSTER_ISSUER_NAME__
    kind: ClusterIssuer
    group: cert-manager.io
