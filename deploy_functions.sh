#!/usr/bin/env bash

set -euo pipefail

if ! command -v yc >/dev/null 2>&1; then
  echo "yc CLI not found. Install and authenticate with 'yc init'." >&2
  exit 1
fi

: "${JWT_SECRET_KEY:?JWT_SECRET_KEY env var must be set}"
: "${YDB_ENDPOINT:?YDB_ENDPOINT env var must be set}"
: "${YDB_DATABASE:?YDB_DATABASE env var must be set}"

SERVICE_ACCOUNT_ID="aje6aqidkl72tp8qttce"
RUNTIME="python39"
ENTRYPOINT="index.handler"
MEMORY="512m"
TIMEOUT="30s"

deploy() {
  local name="$1"; shift
  local src="$1"; shift
  echo "\nDeploying ${name} from ${src} ..."
  yc serverless function version create \
    --function-name="${name}" \
    --runtime="${RUNTIME}" \
    --entrypoint="${ENTRYPOINT}" \
    --memory="${MEMORY}" \
    --execution-timeout="${TIMEOUT}" \
    --service-account-id="${SERVICE_ACCOUNT_ID}" \
    --source-path="${src}" \
    --environment JWT_SECRET_KEY="${JWT_SECRET_KEY}" \
    --environment YDB_ENDPOINT="${YDB_ENDPOINT}" \
    --environment YDB_DATABASE="${YDB_DATABASE}" | cat
}

echo "Starting deployment of updated functions..."
deploy list-installments      functions/list-installments/

echo "\nAll selected functions deployed successfully."