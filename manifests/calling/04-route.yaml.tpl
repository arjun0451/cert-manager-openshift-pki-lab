apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: __CALLING_APP_NAME__
  namespace: __CALLING_NAMESPACE__
  labels:
    app: pki-lab
    pki-lab-owned: "true"
    component: calling
spec:
  host: __CALLING_APP_NAME__.__APPS_DOMAIN__
  to:
    kind: Service
    name: __CALLING_APP_NAME__
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: None
