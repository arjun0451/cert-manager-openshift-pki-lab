apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config-__EDGE_ROUTE_APP_NAME__
  namespace: __EDGE_ROUTE_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: edge-route
data:
  nginx.conf: |
    events {}
    http {
      access_log /dev/stdout;
      server_tokens off;
      server {
        listen 8080;
        server_name _;
        location = /health { access_log off; return 200 "OK\n"; add_header Content-Type text/plain; }
        location = / {
          default_type text/html;
          return 200 '<!doctype html><html><head><title>__EDGE_ROUTE_APP_NAME__</title></head><body><h1>__EDGE_ROUTE_APP_NAME__</h1><p>External HTTPS terminates at the OpenShift router.</p><p>Backend transport seen by this pod: <strong>$scheme</strong>.</p><p>Forwarded client protocol: <strong>$http_x_forwarded_proto</strong>.</p></body></html>';
        }
      }
    }
