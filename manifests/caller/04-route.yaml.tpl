apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: __CALLER_APP_NAME__
  namespace: __CALLER_NAMESPACE__
  labels:
    app: pki-lab
    pki-lab-owned: "true"
    component: caller
spec:
  host: __CALLER_APP_NAME__.__APPS_DOMAIN__
  to:
    kind: Service
    name: __CALLER_APP_NAME__
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: None
