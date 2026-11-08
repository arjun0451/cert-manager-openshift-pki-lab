apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: __APP_NAME__-tls
  namespace: __NAMESPACE__
  labels:
    app: pki-lab
spec:
  secretName: __SECRET_NAME__
  commonName: __APP_NAME__
  duration: 2160h
  renewBefore: 720h
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
    name: __ISSUER_NAME__
    kind: ClusterIssuer
    group: cert-manager.io
