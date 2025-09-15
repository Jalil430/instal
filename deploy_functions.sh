#!/usr/bin/env bash

set -euo pipefail

if ! command -v yc >/dev/null 2>&1; then
  echo "yc CLI not found. Install and authenticate with 'yc init'." >&2
  exit 1
fi

: "${API_KEY:?API_KEY env var must be set}"
: "${JWT_SECRET_KEY:?JWT_SECRET_KEY env var must be set}"
: "${YDB_ENDPOINT:?YDB_ENDPOINT env var must be set}"
: "${YDB_DATABASE:?YDB_DATABASE env var must be set}"

SERVICE_ACCOUNT_ID="aje6aqidkl72tp8qttce"
RUNTIME="python39"
ENTRYPOINT="index.handler"
MEMORY="1024m"
TIMEOUT="45s"

ensure_function() {
  local name="$1"
  yc serverless function create --name "$name" >/dev/null 2>&1 || true
}

deploy() {
  local name="$1"; shift
  local src="$1"; shift
  echo "Deploying ${name} from ${src} ..."
  yc serverless function version create \
    --function-name="${name}" \
    --runtime="${RUNTIME}" \
    --entrypoint="${ENTRYPOINT}" \
    --memory="${MEMORY}" \
    --execution-timeout="${TIMEOUT}" \
    --service-account-id="${SERVICE_ACCOUNT_ID}" \
    --source-path="${src}" \
    --environment API_KEY="${API_KEY}" \
    --environment JWT_SECRET_KEY="${JWT_SECRET_KEY}" \
    --environment YDB_ENDPOINT="${YDB_ENDPOINT}" \
    --environment YDB_DATABASE="${YDB_DATABASE}" >/dev/null
  yc serverless function get --name "${name}" --format json | jq -r '.id'
}

echo "Starting deployment (full mode)."
echo "Tip: source deploy_env.sh before running this script."

# Functions to exclude (investor-related slated for removal)
EXCLUDE_FUNCS=(
  "create-investor"
  "list-investors"
  "search-investors"
  "get-investor"
  "update-investor"
  "delete-investor"
)

is_excluded() {
  local candidate="$1"
  for ex in "${EXCLUDE_FUNCS[@]}"; do
    if [[ "$candidate" == "$ex" ]]; then
      return 0
    fi
  done
  return 1
}

echo ""
echo "Deployed function IDs:"

if [[ "$#" -gt 0 ]]; then
  # Deploy only functions passed as args
  for name in "$@"; do
    if is_excluded "$name"; then
      echo "Skipping excluded function: ${name}"
      continue
    fi
    dir="functions/${name}/"
    if [[ ! -f "${dir}index.py" ]]; then
      echo "Warning: source not found for ${name} at ${dir}index.py" >&2
      continue
    fi
    ensure_function "$name"
    id=$(deploy "$name" "$dir")
    printf "  %-32s %s\n" "$name" "$id"
  done
else
  # Discover and deploy all functions (excluding investor-related)
  for dir in functions/*/ ; do
    name="$(basename "$dir")"
    [[ -f "${dir}index.py" ]] || continue
    if is_excluded "$name"; then
      echo "Skipping excluded function: ${name}"
      continue
    fi
    ensure_function "$name"
    id=$(deploy "$name" "$dir")
    printf "  %-32s %s\n" "$name" "$id"
  done
fi

echo ""

# Optionally deploy API Gateway if DEPLOY_GATEWAY=1 is set
if [[ "${DEPLOY_GATEWAY:-0}" == "1" ]]; then
  deploy_api_gateway() {
    local spec_file="instal-api.yaml"
    local gateway_name="instal-api"
    [[ -f "$spec_file" ]] || { echo "API spec $spec_file not found" >&2; return 1; }

    if yc serverless api-gateway get --name "$gateway_name" >/dev/null 2>&1; then
      echo "Updating API Gateway: $gateway_name"
      yc serverless api-gateway update --name "$gateway_name" --spec "$spec_file" >/dev/null
    else
      echo "Creating API Gateway: $gateway_name"
      yc serverless api-gateway create --name "$gateway_name" --spec "$spec_file" >/dev/null
    fi

    yc serverless api-gateway get --name "$gateway_name" --format json | jq -r '.domain // .status.domain // "(domain unavailable)"'
  }

  echo "Deploying API Gateway (DEPLOY_GATEWAY=1)"
  deploy_api_gateway || echo "API Gateway deployment failed" >&2
  echo ""
fi

echo "Deployment complete."
