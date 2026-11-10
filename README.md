# cert-manager OpenShift PKI Lab

This repository demonstrates three OpenShift certificate-management scenarios:

| Scenario | Purpose | Entry point |
| --- | --- | --- |
| Base mTLS | Two NGINX applications authenticate each other over service DNS. | `make bootstrap` |
| Edge Route | The OpenShift router terminates external TLS and forwards HTTP to NGINX. | `make edge-route` |
| trust-manager mTLS | Two additional NGINX applications consume a PEM and PKCS#12 trust bundle. | `make trustbundle-mtls` |

The lab is intended for non-production clusters. Generated local CA material and local configuration are ignored by Git.

## Architecture

The Root CA is generated locally and remains outside the cluster. The Intermediate CA keypair is imported into `cert-manager/ca-key-pair`, where `external-intermediate-ca` signs workload certificates.

The base scenario issues exactly two dual-purpose leaf certificates: one for `caller-app` and one for `calling-app`. Each has `serverAuth` and `clientAuth` EKUs and is used for both inbound TLS and outbound mTLS authentication. NGINX verifies peer certificates and hostnames for upstream requests. Its external HTTPS listener uses `ssl_verify_client optional`, allowing the demonstration page to load in a browser while application-to-application calls remain mutual TLS.

Service Routes use TLS passthrough. The optional edge scenario is different: its Route uses edge termination, presents the cert-manager certificate through `externalCertificate`, and forwards HTTP to the NGINX pod. The trust-manager scenario adds two separate leaf certificates and Routes for its own applications.

## Prerequisites

- OpenShift with an authenticated `oc` session and permissions to create the listed resources.
- cert-manager and its `Certificate` and `ClusterIssuer` APIs.
- `bash`, `make`, `openssl`, and `oc`.
- An existing cert-manager namespace; the default is `cert-manager`.

Before a cluster operation, operators should run the offline checks:

```bash
make test
make validate
```

## Configuration

Operators may copy the committed template without committing the result:

```bash
cp config/lab.env.example config/lab.env
```

Explicit process environment variables take precedence over `config/lab.env`; values in that file take precedence over defaults. `APPS_DOMAIN` accepts either `apps.example.com` or `*.apps.example.com`. When it is empty, the lab discovers the cluster ingress domain if permitted; offline rendering uses `APPS_DOMAIN_FALLBACK`.

Important settings include `CALLER_NAMESPACE`, `CALLING_NAMESPACE`, application names, `CERTIFICATE_DURATION`, `CERTIFICATE_RENEW_BEFORE`, `CREATE_ROUTES`, and `INCLUDE_ROUTE_SANS`. The default 60-minute duration and 10-minute renewal window are intentionally short for lab rotation tests.

## Base mTLS workflow

```bash
make prereqs
make bootstrap
make verify-pki
make verify-certs
make verify-mtls
```

`make bootstrap` preserves existing Root and Intermediate material. `make verify-mtls` proves mTLS in both service directions and separately proves browser-style HTTPS without a client certificate.

## Optional scenarios

```bash
# Edge termination at the OpenShift router
make edge-route
make verify-edge-route

# trust-manager prerequisite and PKCS#12 bundle scenario
make trust-manager
make trustbundle-mtls
make verify-trustbundle-mtls
```

The trust-manager operand is a cluster-scoped OpenShift Technology Preview feature. Before `make trust-manager`, the cert-manager Operator Subscription must have `UNSUPPORTED_ADDON_FEATURES=TrustManager=true`. See [the trust-manager guide](docs/trust-manager-mtls.md).

## Local rendering and cleanup

```bash
make render
make validate

CLEANUP_DRY_RUN=true make clean
CLEANUP_DRY_RUN=true make clean-edge-route
CLEANUP_DRY_RUN=true make clean-trustbundle-mtls
```

Rendering and validation do not require cluster connectivity. Cleanup only deletes labelled lab resources and namespaces created by the lab. It retains the local Root and Intermediate CA material. The shared `TrustManager` operand is deliberately not removed by scenario cleanup.

## Documentation

- [Quick start](QUICKSTART.md)
- [Architecture](docs/architecture.md)
- [Certificate flow](docs/certificate-flow.md)
- [Edge Route flow](docs/edge-route-flow.md)
- [trust-manager mTLS flow](docs/trust-manager-mtls.md)
- [Validation cases](docs/test-cases.md)
- [Troubleshooting](docs/troubleshooting.md)

For disconnected clusters, operators should mirror `curlimages/curl:8.10.1` and update the verification scripts to use the approved internal image.
