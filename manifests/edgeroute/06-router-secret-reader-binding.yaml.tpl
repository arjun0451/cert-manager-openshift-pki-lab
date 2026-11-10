apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edge-route-tls-reader
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: edge-route
subjects:
- kind: ServiceAccount
  name: router
  namespace: openshift-ingress
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: edge-route-tls-reader
