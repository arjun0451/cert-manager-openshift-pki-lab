apiVersion: v1
kind: Service
metadata:
  name: __TRUST_APP_NAME__
  namespace: __TRUST_NAMESPACE__
  labels:
    app: pki-lab
    component: trust-mtls
    pki-lab-owned: "true"
spec:
  selector:
    app: __TRUST_DEPLOYMENT_NAME__
    component: trust-mtls
  ports:
  - name: https
    port: 443
    targetPort: https
  - name: http
    port: 8080
    targetPort: http
