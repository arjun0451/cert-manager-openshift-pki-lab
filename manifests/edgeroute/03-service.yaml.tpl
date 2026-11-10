apiVersion: v1
kind: Service
metadata:
  name: __EDGE_ROUTE_SERVICE_NAME__
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: edge-route
spec:
  type: ClusterIP
  selector:
    app: __EDGE_ROUTE_APP_NAME__
    component: edge-route
  ports:
  - name: http
    port: 8080
    targetPort: http
    protocol: TCP
