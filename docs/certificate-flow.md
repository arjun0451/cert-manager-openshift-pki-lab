# Certificate Flow

1. `00_generate_root_ca.sh` creates an offline 4096-bit Root CA.
2. `01_generate_intermediate_ca.sh` creates a 4096-bit Intermediate key/CSR and signs it with the Root CA.
3. `04_import_intermediate_secret.sh` imports the Intermediate certificate/key and the public Root certificate into `cert-manager/ca-key-pair`; the Root private key is never imported.
4. The same script distributes a public-only bundle (Intermediate + Root) to each application namespace.
5. `05_create_clusterissuer.sh` creates the CA ClusterIssuer.
6. `06_create_certificates.sh` discovers the cluster apps domain and renders two Certificate resources. Each certificate requests `server auth` and `client auth` usages.
7. cert-manager creates one Secret per app containing `tls.crt` and `tls.key`.
8. Each NGINX mounts its own identity Secret and the public trust ConfigMap. The identity Secret is used for both server and client TLS.
9. NGINX requires client authentication on 8443. The 8080 health endpoint is separate and unauthenticated only for probes.

The test script validates both directions with curl using `--cacert`, `--cert`, and `--key`; it also confirms that a request without a client certificate fails.
