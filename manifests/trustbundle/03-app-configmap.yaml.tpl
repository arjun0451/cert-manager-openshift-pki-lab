apiVersion: v1
kind: ConfigMap
metadata:
  name: __TRUST_CONFIGMAP_NAME__
  namespace: __TRUST_NAMESPACE__
  labels:
    app: pki-lab
    component: trust-mtls
    pki-lab-owned: "true"
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
        ssl_verify_client optional;
        ssl_verify_depth 2;
        ssl_protocols TLSv1.2 TLSv1.3;
        location = /health { access_log off; return 200 "OK\n"; add_header Content-Type text/plain; }
        location = / { default_type text/html; return 200 '<!doctype html><html><body><h1>__TRUST_APP_NAME__</h1><p>mTLS trust: PEM and PKCS#12 bundle files are mounted.</p><button onclick="fetch(&quot;/call-peer&quot;).then(function(r){document.getElementById(&quot;result&quot;).textContent=r.ok ? &quot;Calling __TRUST_PEER_NAME__ succeeded (HTTP &quot;+r.status+&quot;). Backend mTLS verified.&quot; : &quot;Calling __TRUST_PEER_NAME__ failed (HTTP &quot;+r.status+&quot;).&quot;;})">Call __TRUST_PEER_NAME__</button><pre id="result"></pre></body></html>'; }
        location = /call-peer {
          proxy_pass https://__TRUST_PEER_NAME__.__TRUST_PEER_NAMESPACE__.svc.cluster.local:443/;
          proxy_ssl_certificate /etc/nginx/certs/tls.crt;
          proxy_ssl_certificate_key /etc/nginx/certs/tls.key;
          proxy_ssl_trusted_certificate /etc/nginx/trust/ca-bundle.crt;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 2;
          proxy_ssl_server_name on;
          proxy_ssl_name __TRUST_PEER_NAME__.__TRUST_PEER_NAMESPACE__.svc.cluster.local;
          proxy_set_header Host __TRUST_PEER_NAME__.__TRUST_PEER_NAMESPACE__.svc.cluster.local;
        }
      }
      server { listen 8080; server_name _; location = /health { access_log off; return 200 "OK\n"; } location / { return 404; } }
    }
