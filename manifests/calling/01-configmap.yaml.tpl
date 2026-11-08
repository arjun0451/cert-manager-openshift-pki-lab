apiVersion: v1
kind: ConfigMap
metadata:
  name: __CALLING_CONFIGMAP_NAME__
  namespace: __CALLING_NAMESPACE__
  labels:
    pki-lab-owned: "true"
  labels:
    app: pki-lab
    component: calling
data:
  nginx.conf: |
    worker_processes auto;
    error_log /dev/stderr warn;
    pid /tmp/nginx.pid;
    events { worker_connections 1024; }
    http {
      access_log /dev/stdout;
      server_tokens off;
      server {
        listen 8443 ssl;
        server_name _;
        ssl_certificate /etc/nginx/certs/tls.crt;
        ssl_certificate_key /etc/nginx/certs/tls.key;
        ssl_client_certificate /etc/nginx/trust/ca-bundle.crt;
        ssl_verify_client on;
        ssl_verify_depth 2;
        ssl_protocols TLSv1.2 TLSv1.3;
        location = /health { return 200 "OK\n"; add_header Content-Type text/plain; }
        location = / { return 200 "__CALLING_APP_NAME__ - mTLS identity active\n"; add_header Content-Type text/plain; }
        location = /call-peer {
          proxy_pass https://__CALLER_APP_NAME__.__CALLER_NAMESPACE__.svc.cluster.local:443/;
          proxy_ssl_certificate /etc/nginx/certs/tls.crt;
          proxy_ssl_certificate_key /etc/nginx/certs/tls.key;
          proxy_ssl_trusted_certificate /etc/nginx/trust/ca-bundle.crt;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 2;
          proxy_ssl_server_name on;
          proxy_ssl_name __CALLER_APP_NAME__.__CALLER_NAMESPACE__.svc.cluster.local;
          proxy_set_header Host __CALLER_APP_NAME__.__CALLER_NAMESPACE__.svc.cluster.local;
          proxy_connect_timeout 10s;
          proxy_read_timeout 30s;
        }
      }
      server {
        listen 8080;
        server_name _;
        location = /health { access_log off; return 200 "OK\n"; add_header Content-Type text/plain; }
        location / { return 404; }
      }
    }
