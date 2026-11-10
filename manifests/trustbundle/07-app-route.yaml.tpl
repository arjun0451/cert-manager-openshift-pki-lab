apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: __TRUST_APP_NAME__
  namespace: __TRUST_NAMESPACE__
  labels:
    app: pki-lab
    component: trust-mtls
    pki-lab-owned: "true"
spec:
  host: __TRUST_APP_NAME__.__APPS_DOMAIN__
  to:
    kind: Service
    name: __TRUST_APP_NAME__
  port:
    targetPort: https
  tls:
    termination: passthrough
