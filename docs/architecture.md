# Architecture

The diagrams describe the resources created by the lab and the reconciliation paths that keep certificates and trust data current. Mermaid renders directly in GitHub and remains aligned with the manifests.

## Base certificate reconciliation

```mermaid
flowchart LR
  root["🔐 Offline Root CA\nlocal certs/root"]
  intermediate["🔐 Intermediate CA\nlocal certs/intermediate"]

  subgraph cluster["☸️ OpenShift cluster"]
    subgraph cmns["Namespace: cert-manager"]
      cakey["🔑 Secret: ca-key-pair\nIntermediate key + chain"]
      issuer["📜 ClusterIssuer\nexternal-intermediate-ca"]
      controller["⚙️ cert-manager controller"]
    end

    subgraph callerNs["Namespace: caller-ns"]
      callerCert["📜 Certificate\ncaller-app-tls"]
      callerSecret["🔑 Secret\ncaller-app-tls-secret"]
      callerTrust["📦 ConfigMap\npki-trust-bundle"]
      callerApp["⚙️ Deployment\nnginx-caller-app"]
    end

    subgraph callingNs["Namespace: calling-ns"]
      callingCert["📜 Certificate\ncalling-app-tls"]
      callingSecret["🔑 Secret\ncalling-app-tls-secret"]
      callingTrust["📦 ConfigMap\npki-trust-bundle"]
      callingApp["⚙️ Deployment\nnginx-calling-app"]
    end
  end

  root -->|signs| intermediate
  intermediate -->|imported by make issuer| cakey
  cakey --> issuer
  controller -->|reconciles| callerCert
  controller -->|reconciles| callingCert
  issuer -->|signs| callerCert
  issuer -->|signs| callingCert
  callerCert -->|writes tls.crt, tls.key, ca.crt| callerSecret
  callingCert -->|writes tls.crt, tls.key, ca.crt| callingSecret
  intermediate -->|public chain only| callerTrust
  intermediate -->|public chain only| callingTrust
  callerSecret -->|mounted at /etc/nginx/certs| callerApp
  callerTrust -->|mounted at /etc/nginx/trust| callerApp
  callingSecret -->|mounted at /etc/nginx/certs| callingApp
  callingTrust -->|mounted at /etc/nginx/trust| callingApp
```

The Root private key never enters the cluster. The `ca-key-pair` Secret contains the Intermediate signing key and the public Root certificate. cert-manager reconciles each `Certificate` and updates its target Secret at issuance and renewal.

## Base application traffic and namespace resources

```mermaid
flowchart LR
  subgraph callerNs["☸️ caller-ns"]
    callerRoute["🌐 Route: caller-app\nTLS passthrough"]
    callerSvc["🔀 Service: caller-app\n443 → 8443"]
    callerPod["⚙️ nginx-caller-app Pod\nserver TLS + mTLS client"]
  end

  subgraph callingNs["☸️ calling-ns"]
    callingRoute["🌐 Route: calling-app\nTLS passthrough"]
    callingSvc["🔀 Service: calling-app\n443 → 8443"]
    callingPod["⚙️ nginx-calling-app Pod\nserver TLS + mTLS client"]
  end

  browser["🌐 Browser or external client"] --> callerRoute --> callerSvc --> callerPod
  browser --> callingRoute --> callingSvc --> callingPod
  callerPod -->|mTLS, peer SAN verification| callingSvc
  callingPod -->|mTLS, peer SAN verification| callerSvc
```

Both applications use their own dual-EKU leaf keypair for inbound TLS and outbound mTLS. NGINX allows browser HTTPS without a client certificate, while its upstream calls always present a certificate and validate the peer hostname and CA chain. Port 8080 remains limited to health probes.

## Optional scenarios

```mermaid
flowchart LR
  client["🌐 External client"]

  subgraph edge["Edge Route scenario"]
    router["🔀 OpenShift router\nedge TLS termination"]
    edgeSecret["🔑 edge-route-tls\ncert-manager managed"]
    edgeSvc["🔀 nginx-edge-service"]
    edgePod["⚙️ nginx-edge-app\nHTTP :8080"]
    client -->|HTTPS| router -->|HTTP| edgeSvc --> edgePod
    edgeSecret -->|externalCertificate reference| router
  end

  subgraph trust["trust-manager mTLS scenario"]
    bundle["📜 Bundle\npki-lab-java-trust-bundle"]
    trustCaller["☸️ trust-caller-ns\nPEM + PKCS#12 ConfigMap"]
    trustCalling["☸️ trust-calling-ns\nPEM + PKCS#12 ConfigMap"]
    bundle -->|reconciles selected namespaces| trustCaller
    bundle -->|reconciles selected namespaces| trustCalling
  end
```

The edge Route intentionally terminates TLS at the router and is not end-to-end encryption. The trust-manager Bundle publishes `ca-bundle.crt` for NGINX and `ca-bundle.p12` for Java-compatible consumers; neither file contains a private key.
