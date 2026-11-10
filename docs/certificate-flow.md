# Certificate Flow

1. `make root-ca` creates the offline Root CA only when absent.
2. `make intermediate` creates the Intermediate CA signed by that Root.
3. `make issuer` imports the Intermediate certificate/key into `cert-manager/ca-key-pair` and creates `external-intermediate-ca`.
4. `make certs` requests the two base application leaf certificates.
5. cert-manager writes `tls.crt`, `tls.key`, and, when the issuer reports it, `ca.crt` to each target Secret.

`tls.crt` is the serving certificate chain and `tls.key` is the corresponding private key. The optional `ca.crt` is issuer information; applications should use the separately distributed trust bundle rather than mount a serving Secret merely to obtain CA data.

The base application Certificates contain service DNS SANs. When `INCLUDE_ROUTE_SANS=true`, the configured Route host is also included. The edge and trust-manager scenarios request their own leaf certificates; they do not alter the two base Certificates.

Certificate rotation follows `CERTIFICATE_DURATION` and `CERTIFICATE_RENEW_BEFORE`. cert-manager updates mounted Secret files, but NGINX reads its certificate at startup. Operators should restart the affected Deployment after a renewal unless an explicit reload mechanism exists.
