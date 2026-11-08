# cert-manager OpenShift PKI Lab

A reproducible OpenShift lab for an offline Root CA, an online Intermediate CA managed by cert-manager, and two NGINX applications using **mutual TLS in both directions**.

## Design

- The Root CA private key remains local/offline and is never sent to the cluster.
- The Intermediate CA certificate and private key are stored in `cert-manager/ca-key-pair` for the CA `ClusterIssuer`; the Secret also carries the public Root certificate as `ca.crt`. The Root private key is never imported.
- The Root and Intermediate **public certificates** are distributed to both app namespaces as `pki-trust-bundle`.
- Exactly two leaf certificates are issued: `caller-app-tls-secret` and `calling-app-tls-secret`.
- Each leaf certificate has both `serverAuth` and `clientAuth` EKUs. Each application reuses its own keypair for inbound server TLS and outbound client authentication.
- NGINX requires a client certificate on its TLS listener. Its separate HTTP listener on 8080 is only for Kubernetes health probes.
- Routes use TLS passthrough. `CREATE_ROUTES` and `INCLUDE_ROUTE_SANS` are independent; an explicit apps domain is used as-is (except a leading `*.` is normalized), then discovery, then the configured local fallback.

```text
Offline Root CA (private key stays offline)
       |
       +-- signs --> Intermediate CA
                         |
                         +-- cert-manager ClusterIssuer
                               |                    |
                         caller-app cert       calling-app cert
                         serverAuth+clientAuth serverAuth+clientAuth
                               |                    |
                         caller NGINX  <---mTLS---> calling NGINX
```

## Prerequisites

- OpenShift 4.16+ and `oc` authenticated with permission to create namespaces, Routes, Secrets, ConfigMaps, Deployments and a ClusterIssuer.
- cert-manager CRDs/controller installed; `ClusterIssuer` and `Certificate` APIs available.
- `openssl`, `bash`, `make`; Python is not required.
- The selected cert-manager namespace (default `cert-manager`) exists.

## Configure

```bash
cp config/lab.env.example config/lab.env
# Exported environment variables override this file. Set APPS_DOMAIN explicitly
# for a cluster-specific value, or use APPS_DOMAIN_FALLBACK for offline rendering.
```

The domain is discovered using:

```bash
oc get ingress.config/cluster -o jsonpath='{.spec.domain}'
```

All resources are rendered from lightweight templates at runtime. For in-cluster-only mTLS, set `CREATE_ROUTES=false` and `INCLUDE_ROUTE_SANS=false` independently as needed.

## Offline rendering and validation

```bash
make render    # write configured manifests to rendered/ without contacting OpenShift
make validate  # check rendered names, SANs, EKUs, Routes, shell syntax, and an existing CA chain
make test      # exercise configuration precedence and render combinations
```

## Bootstrap from a fresh environment

```bash
make bootstrap
# equivalent:
make all
```

The Makefile performs PKI generation, chain verification, namespace creation, CA Secret/trust-bundle creation, ClusterIssuer setup, two Certificate requests, application deployment, and mTLS tests. Existing Root/Intermediate keys are not overwritten.

## Step-by-step

```bash
scripts/00_generate_root_ca.sh
scripts/01_generate_intermediate_ca.sh
scripts/02_verify_chain.sh
scripts/03_create_namespaces.sh
scripts/04_import_intermediate_secret.sh
scripts/05_create_clusterissuer.sh
scripts/06_create_certificates.sh
scripts/07_verify_certificates.sh
scripts/08_deploy_caller_nginx.sh
scripts/09_deploy_calling_nginx.sh
scripts/10_verify_mtls.sh
```

## Certificate details

| Certificate | Namespace | Secret | EKUs | DNS SANs |
|---|---|---|---|---|
| caller-app | caller-ns | caller-app-tls-secret | serverAuth, clientAuth | service DNS + discovered Route host |
| calling-app | calling-ns | calling-app-tls-secret | serverAuth, clientAuth | service DNS + discovered Route host |

The `tls.crt` data from cert-manager is mounted as both the NGINX server certificate and the outbound mTLS client certificate. No separate client certificate resources are created.

## Verification

```bash
oc get clusterissuer external-intermediate-ca
oc get certificate -n caller-ns
oc get certificate -n calling-ns
oc get route -n caller-ns
oc get route -n calling-ns
make verify-mtls
```

The test creates short-lived curl pods. Positive tests validate the Root+Intermediate trust chain and hostname while presenting the caller/calling identity. Negative tests verify that a client without a certificate is rejected. No `curl -k` is used.

For manual external access, use a trusted client certificate and key, for example:

```bash
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/caller-app.crt
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/caller-app.key
chmod 600 /tmp/caller-app.key
curl --cacert certs/ca-bundle.crt --cert /tmp/caller-app.crt --key /tmp/caller-app.key \
  "https://caller-app.$(oc get ingress.config/cluster -o jsonpath='{.spec.domain}')/"
rm -f /tmp/caller-app.crt /tmp/caller-app.key
```

This exports an application private key from the cluster. Use a dedicated external client identity in production and protect/delete any temporary key material securely.

## Cleanup

```bash
make clean
# preview only:
CLEANUP_DRY_RUN=true make clean
```

Cleanup is scoped to lab-named resources. It deletes a namespace only when this bootstrap created it (`pki-lab-created=true`); pre-existing namespaces are preserved. The ClusterIssuer and cert-manager Secret are deleted only when labelled `app=pki-lab`. Generated local CA material under `certs/` is intentionally retained; securely archive or remove it yourself.

## Repository layout

- `openssl/`: Root and Intermediate CA profiles/extensions.
- `scripts/`: numbered bootstrap, issuance, deployment and verification scripts; `scripts/lib/common.sh` provides shared configuration and domain discovery.
- `config/`: optional lab configuration.
- `manifests/`: namespace, ClusterIssuer, Certificate template, application ConfigMaps, Deployments and Services.
- `certs/`: generated local PKI material (gitignored).
- `docs/`: architecture, certificate flow, test cases and troubleshooting.

## Important operational notes

- This is a lab, not a complete production PKI service. Protect CA keys, back up the Intermediate CA securely, and plan CA rotation/revocation.
- A cert-manager CA issuer does not automatically rotate its signing CA. Rotate the Intermediate CA deliberately.
- NGINX reads mounted Secret files at startup. Secret updates do not guarantee NGINX reload; certificate renewal/reload behavior should be validated for your chosen image and deployment. Restart workloads after renewal if required.
- The test scripts use `curlimages/curl:8.10.1`; mirror this image into an approved internal registry for disconnected clusters.
