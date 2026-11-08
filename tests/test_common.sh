#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="$(mktemp)"
trap 'rm -f "$config_file"' EXIT
cat > "$config_file" <<'EOF'
CALLER_NAMESPACE=file-caller
CALLING_NAMESPACE=file-calling
CALLER_APP_NAME=file-caller-app
CALLING_APP_NAME=file-calling-app
APPS_DOMAIN=*.file.apps.example.com
EOF

CONFIG_FILE="$config_file" CALLER_NAMESPACE=environment-caller bash -c '
  source "'$PROJECT_DIR'/scripts/lib/common.sh"
  [[ "$CALLER_NAMESPACE" == environment-caller ]]
  [[ "$CALLING_NAMESPACE" == file-calling ]]
  [[ "$(resolve_apps_domain)" == file.apps.example.com ]]
'

CONFIG_FILE="$config_file" APPS_DOMAIN=apps.environment.example.com bash -c '
  source "'$PROJECT_DIR'/scripts/lib/common.sh"
  [[ "$(resolve_apps_domain)" == apps.environment.example.com ]]
'

RENDER_OFFLINE=true APPS_DOMAIN= APPS_DOMAIN_FALLBACK=local.apps.example.test bash -c '
  source "'$PROJECT_DIR'/scripts/lib/common.sh"
  [[ "$(resolve_apps_domain)" == local.apps.example.test ]]
'
