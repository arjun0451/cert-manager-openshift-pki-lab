apiVersion: v1
kind: Service
metadata:
  name: __CALLING_APP_NAME__
  namespace: __CALLING_NAMESPACE__
  labels:
    pki-lab-owned: "true"
spec:
  type: ClusterIP
  selector:
    app: __CALLING_DEPLOYMENT_NAME__
    component: calling
  ports:
    - name: https
      port: 443
      targetPort: https
      protocol: TCP
