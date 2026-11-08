apiVersion: v1
kind: Service
metadata:
  name: __CALLER_APP_NAME__
  namespace: __CALLER_NAMESPACE__
  labels:
    pki-lab-owned: "true"
spec:
  type: ClusterIP
  selector:
    app: __CALLER_DEPLOYMENT_NAME__
    component: caller
  ports:
    - name: https
      port: 443
      targetPort: https
      protocol: TCP
