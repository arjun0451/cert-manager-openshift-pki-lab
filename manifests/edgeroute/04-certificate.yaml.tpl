apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: edge-route-cert
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    app: pki-lab
    component: edge-route
    pki-lab-owned: "true"
spec:
  secretName: __EDGE_ROUTE_TLS_SECRET__
  commonName: __EDGE_ROUTE_NAME__.__APPS_DOMAIN__
  dnsNames:
  - __EDGE_ROUTE_NAME__.__APPS_DOMAIN__
  duration: __CERTIFICATE_DURATION__
  renewBefore: __CERTIFICATE_RENEW_BEFORE__
  usages:
  - digital signature
  - key encipherment
  - server auth
  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always
  issuerRef:
    name: __CLUSTER_ISSUER_NAME__
    kind: ClusterIssuer
    group: cert-manager.io
