apiVersion: apps/v1
kind: Deployment
metadata:
  name: __EDGE_ROUTE_APP_NAME__
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    app: __EDGE_ROUTE_APP_NAME__
    component: edge-route
    pki-lab-owned: "true"
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: __EDGE_ROUTE_APP_NAME__
      component: edge-route
  template:
    metadata:
      labels:
        app: __EDGE_ROUTE_APP_NAME__
        component: edge-route
        pki-lab-owned: "true"
    spec:
      serviceAccountName: default
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - __EDGE_ROUTE_APP_NAME__
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: quay.io/nginx/nginx-unprivileged:stable-perl
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run/nginx
        - name: nginx-tmp
          mountPath: /tmp
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        startupProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 2
          failureThreshold: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config-__EDGE_ROUTE_APP_NAME__
          defaultMode: 0644
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
      - name: nginx-tmp
        emptyDir: {}
