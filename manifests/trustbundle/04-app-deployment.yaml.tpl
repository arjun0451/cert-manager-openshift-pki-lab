apiVersion: apps/v1
kind: Deployment
metadata:
  name: __TRUST_DEPLOYMENT_NAME__
  namespace: __TRUST_NAMESPACE__
  labels:
    app: __TRUST_DEPLOYMENT_NAME__
    component: trust-mtls
    pki-lab-owned: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: __TRUST_DEPLOYMENT_NAME__
      component: trust-mtls
  template:
    metadata:
      labels:
        app: __TRUST_DEPLOYMENT_NAME__
        component: trust-mtls
        pki-lab-owned: "true"
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: nginx
        image: quay.io/nginx/nginx-unprivileged:stable-perl
        ports:
        - name: https
          containerPort: 8443
        - name: http
          containerPort: 8080
        volumeMounts:
        - {name: server-certs, mountPath: /etc/nginx/certs, readOnly: true}
        - {name: trust-bundle, mountPath: /etc/nginx/trust, readOnly: true}
        - {name: nginx-config, mountPath: /etc/nginx/nginx.conf, subPath: nginx.conf, readOnly: true}
        - {name: nginx-cache, mountPath: /var/cache/nginx}
        - {name: nginx-run, mountPath: /var/run/nginx}
        - {name: nginx-tmp, mountPath: /tmp}
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities: {drop: [ALL]}
        resources:
          requests: {memory: 64Mi, cpu: 50m}
          limits: {memory: 256Mi, cpu: 500m}
        startupProbe:
          httpGet: {path: /health, port: http}
          failureThreshold: 10
          periodSeconds: 2
        livenessProbe:
          httpGet: {path: /health, port: http}
        readinessProbe:
          httpGet: {path: /health, port: http}
      volumes:
      - name: server-certs
        secret: {secretName: __TRUST_SECRET_NAME__, defaultMode: 0440}
      - name: trust-bundle
        configMap:
          name: __TRUST_BUNDLE_NAME__
          items:
          - {key: ca-bundle.crt, path: ca-bundle.crt}
          - {key: ca-bundle.p12, path: ca-bundle.p12}
          defaultMode: 0444
      - name: nginx-config
        configMap: {name: __TRUST_CONFIGMAP_NAME__, defaultMode: 0644}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
      - name: nginx-tmp
        emptyDir: {}
