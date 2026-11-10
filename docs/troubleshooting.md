# Troubleshooting

## Configuration or render failure

```bash
make test
make validate
```

Set an explicit `APPS_DOMAIN` for a known cluster domain. For local-only validation, leave it empty and set a valid `APPS_DOMAIN_FALLBACK`. Process environment values override `config/lab.env`.

## ClusterIssuer or Certificate is not Ready

```bash
oc describe clusterissuer external-intermediate-ca
oc describe certificate caller-app-tls -n caller-ns
oc get events -n cert-manager --sort-by=.lastTimestamp
oc get events -n caller-ns --sort-by=.lastTimestamp
```

`ca-key-pair` must contain the Intermediate certificate in `tls.crt`, its matching private key in `tls.key`, and the public Root certificate in `ca.crt`. The Root private key must never be imported into the cluster.

## TLS trust, SAN, or Route failure

```bash
oc get secret caller-app-tls-secret -n caller-ns -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -ext subjectAltName -ext extendedKeyUsage
oc get configmap pki-trust-bundle -n caller-ns -o yaml
oc get route -n caller-ns
```

The certificate must contain the exact Service DNS name and, when enabled, Route hostname. The trust ConfigMap must contain the Intermediate and Root public certificates. Operators should correct trust or SAN configuration rather than bypass verification with `curl -k`.

## NGINX does not serve a renewed certificate

Mounted Secret files can update without causing NGINX to reload. Operators should restart the affected deployment:

```bash
oc rollout restart deployment/nginx-caller-app -n caller-ns
oc rollout status deployment/nginx-caller-app -n caller-ns
```

The trust-bundle deployment workflow performs this restart after certificate reconciliation.

## trust-manager Bundle is not Synced

```bash
oc get trustmanager cluster
oc get deployment trust-manager -n cert-manager
oc describe bundle pki-lab-java-trust-bundle
```

The cert-manager Operator must have `UNSUPPORTED_ADDON_FEATURES=TrustManager=true`. The TrustManager must be Ready, and `TRUST_MANAGER_NAMESPACE` must match its configured trust namespace containing `ca-key-pair`.

## Disconnected cluster

Operators should mirror `curlimages/curl:8.10.1` to an approved registry and replace its references in verification scripts. The same approach applies to the NGINX image when external registries are unavailable.
