# Changelog

## Unreleased

- Added the edge-termination Route scenario with a cert-manager-managed external certificate.
- Added the trust-manager Bundle scenario with PEM and Java-compatible PKCS#12 output, two mTLS workloads, and passthrough Routes.
- Added offline Route, SAN, configuration, and rendering validation for all scenarios.
- Updated cleanup safeguards, certificate reload handling, and operator documentation.

## Initial lab

- Added the offline Root CA, cert-manager Intermediate CA, and base bidirectional NGINX mTLS scenario.
