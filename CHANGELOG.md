# Changelog

## 2.0.0 - 2026-11-04

- Reworked application identity to two dual-EKU leaf certificates (one per app), reused for server and client TLS.
- Added bidirectional mTLS with strict client-certificate verification and verified hostname/trust chain.
- Added public Root + Intermediate trust bundle distribution to both application namespaces.
- Added automatic OpenShift apps-domain discovery and runtime Certificate template rendering.
- Reworked Routes to use the discovered domain rather than a hardcoded lab hostname.
- Added shared configuration helper, `config/lab.env.example`, and a fresh-environment `make bootstrap` flow.
- Updated cleanup to retain local CA material and scope cluster deletion to lab-owned namespaces/resources.
- Rewrote documentation and test cases to match the implemented architecture.
