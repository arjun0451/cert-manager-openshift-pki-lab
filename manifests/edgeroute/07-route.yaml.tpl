apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: __EDGE_ROUTE_NAME__
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    app: pki-lab
    component: edge-route
    pki-lab-owned: "true"
spec:
  host: __EDGE_ROUTE_NAME__.__APPS_DOMAIN__
  to:
    kind: Service
    name: __EDGE_ROUTE_SERVICE_NAME__
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
    externalCertificate:
      name: __EDGE_ROUTE_TLS_SECRET__
