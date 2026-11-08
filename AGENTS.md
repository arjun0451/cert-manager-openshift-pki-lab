# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenShift cert-manager mTLS lab. Numbered scripts in `scripts/` implement the bootstrap flow; shared shell helpers live in `scripts/lib/common.sh`. Kubernetes/OpenShift resources are in `manifests/`: `namespaces/`, `clusterissuer/`, `certificates/`, and one directory per application. CA OpenSSL profiles live in `openssl/`; optional environment overrides start from `config/lab.env.example`. Keep generated PKI material in the gitignored `certs/` directory. Read architecture, certificate-flow, troubleshooting, and test-case notes in `docs/` before changing the flow.

## Build, Test, and Development Commands

Use Bash, OpenSSL, Make, and an authenticated `oc` CLI against a non-production OpenShift cluster.

```bash
make prereqs       # confirm openssl and oc are available
make bootstrap     # generate PKI, configure cert-manager, deploy, and test mTLS
make verify-pki    # validate the local Root → Intermediate chain
make verify-certs  # wait for and inspect issued Certificates
make verify-mtls   # exercise successful and rejected client connections
make clean         # remove only lab-labelled cluster resources
```

For a single stage, run its matching target (for example, `make issuer`) or numbered script. Copy `config/lab.env.example` to `config/lab.env` only for local overrides; never commit credentials or private keys.

## Coding Style & Naming Conventions

Write Bash scripts with `#!/usr/bin/env bash` and `set -euo pipefail`, source `scripts/lib/common.sh`, quote expansions, and fail early through `need`/`require_oc_login`. Preserve the ordered `NN_action.sh` naming for bootstrap stages. Use lowercase, hyphenated Kubernetes resource names and keep manifest filenames descriptive (for example, `app-certificate.yaml.tpl`). Follow existing YAML indentation: two spaces.

## Testing Guidelines

There is no unit-test framework. Treat the verification Make targets as the acceptance suite after every change that affects PKI, manifests, or deployment scripts. Run `make verify-pki`, `make verify-certs`, and `make verify-mtls`; the last target covers both authenticated success and unauthenticated rejection. Update `docs/test-cases.md` when behavior or expected evidence changes.

## Commit & Pull Request Guidelines

The available history contains only an initial checkpoint, so it establishes no detailed convention. Use concise, imperative commit subjects, such as `Validate route SAN configuration`. Keep commits scoped. PRs should explain the affected bootstrap stage, list commands run and results, link the relevant issue when available, and include sanitized `oc` output or screenshots for behavior changes. Never include generated CA keys, Secrets, or cluster credentials.

## Security & Cleanup

Keep the Root private key local; do not import it into the cluster. `make clean` preserves generated CA files under `certs/`; archive or delete them securely yourself.

## Additional Development Requirements

### Configuration and Templating
- Treat `config/lab.env` as the central source of environment-specific configuration.
- Use `config/lab.env.example` as the committed configuration template.
- Namespaces, application names, cert-manager namespace, ClusterIssuer name and OpenShift apps domain must be configurable.
- Avoid hardcoding environment-specific values in scripts, YAML manifests and NGINX configurations.
- Prefer reusable `.yaml.tpl` templates and a lightweight rendering mechanism.
- Do not introduce Helm, Kustomize or additional templating frameworks unless justified.
- Keep Kubernetes API structures and security-sensitive settings explicit.

### OpenShift Domain Discovery
- Support both `apps.example.com` and `*.apps.example.com` inputs.
- Normalize wildcard domains before generating Route hostnames.
- Domain resolution priority:
  1. Explicit user-provided value.
  2. Value from `config/lab.env`.
  3. OpenShift discovery using `oc get ingress.config/cluster -o jsonpath='{.spec.domain}'`, when explicitly configured for automatic discovery.
  4. Documented local-development fallback.
- Never silently override an explicitly configured domain.
- Local validation must work without an OpenShift cluster.

### Namespace Configuration
- Use configured caller, calling and cert-manager namespaces consistently across all generated resources.
- Derive internal service DNS names and certificate SANs from configured application and namespace names.
- Do not assume default namespaces when configuration provides custom values.

### Route Requirements
- Keep Service and Route manifests separate.
- Use `apiVersion: route.openshift.io/v1` and `kind: Route`.
- Use TLS passthrough.
- Keep `CREATE_ROUTES` independent from `INCLUDE_ROUTE_SANS`.
- Do not generate Route manifests using `oc create route --dry-run=client`.

### Local Development and Validation
- The OpenShift cluster may be unavailable during development.
- Provide local validation and manifest rendering that do not require cluster connectivity.
- Add or improve `make validate` and `make render` targets.
- Validate rendered YAML, shell syntax, certificate EKUs, SANs, certificate chains, resource names and namespace consistency.
- Never report successful live deployment or mTLS testing unless actually performed.

### Implementation Principles
- Prefer minimal, maintainable changes.
- Inspect existing implementations before replacing them.
- Avoid duplicated configuration and unnecessary scripts.
- Preserve working functionality and repository structure.
- Explain significant technical decisions before making architectural changes.
- Ask for approval before destructive cluster operations.
- Never regenerate existing CA material without explicit authorization.
