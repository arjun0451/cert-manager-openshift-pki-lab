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
