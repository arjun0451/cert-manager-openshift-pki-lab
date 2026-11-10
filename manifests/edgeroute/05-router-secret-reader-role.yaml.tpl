apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: edge-route-tls-reader
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: edge-route
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["__EDGE_ROUTE_TLS_SECRET__"]
  verbs: ["get", "list", "watch"]
