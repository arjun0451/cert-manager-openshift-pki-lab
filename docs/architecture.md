# Architecture

## Trust hierarchy

Offline Root CA signs an Intermediate CA. The Root private key remains outside the cluster. The Intermediate private key and certificate are held in the cert-manager namespace as `ca-key-pair`, referenced by the `external-intermediate-ca` ClusterIssuer.

The public trust bundle contains the Intermediate certificate followed by the Root certificate. It is published as a ConfigMap in both app namespaces. It contains no private key.

## Application identity

There are exactly two leaf certificates:

- `caller-app-tls-secret` in `caller-ns`
- `calling-app-tls-secret` in `calling-ns`

Each includes service DNS SANs and, by default, a Route SAN generated from the current OpenShift apps domain. Each has both `serverAuth` and `clientAuth` EKUs. The same certificate/key is used for NGINX inbound server TLS and outbound client TLS.

## Mutual TLS

Both NGINX TLS listeners use `ssl_verify_client on` and trust the Root+Intermediate bundle. When caller connects to calling, caller presents its certificate and verifies calling's server certificate and DNS name. The reverse direction works symmetrically. Health probes use a separate HTTP listener and do not weaken the mTLS listener.

Routes are TLS passthrough; the application NGINX process terminates TLS. External Route access therefore also requires a trusted client certificate.
