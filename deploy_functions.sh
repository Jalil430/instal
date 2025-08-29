#!/usr/bin/env bash

set -euo pipefail

if ! command -v yc >/dev/null 2>&1; then
  echo "yc CLI not found. Install and authenticate with 'yc init'." >&2
  exit 1
fi

: "${JWT_SECRET_KEY:?JWT_SECRET_KEY env var must be set}"
: "${YDB_ENDPOINT:?YDB_ENDPOINT env var must be set}"
: "${YDB_DATABASE:?YDB_DATABASE env var must be set}"
: "${API_GATEWAY_ID:?API_GATEWAY_ID env var must be set}"

SERVICE_ACCOUNT_ID="aje6aqidkl72tp8qttce"
RUNTIME="python39"
ENTRYPOINT="index.handler"
MEMORY="512m"
TIMEOUT="30s"

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
    --environment JWT_SECRET_KEY="${JWT_SECRET_KEY}" \
    --environment YDB_ENDPOINT="${YDB_ENDPOINT}" \
    --environment YDB_DATABASE="${YDB_DATABASE}" >/dev/null
  yc serverless function get --name "${name}" --format json | jq -r '.id'
}

echo "Starting deployment (simple mode)."
echo "Tip: source deploy_env.sh before running this script."

# Ensure only the newly created functions exist (as requested)
ensure_function get-wallet-balance
ensure_function list-wallet-balances

# Deploy all wallet-related functions
CREATE_WALLET_ID=$(deploy create-wallet              functions/create-wallet/)
LIST_WALLETS_ID=$(deploy list-wallets                functions/list-wallets/)
GET_WALLET_ID=$(deploy get-wallet                    functions/get-wallet/)
GET_WALLET_BALANCE_ID=$(deploy get-wallet-balance    functions/get-wallet-balance/)
LIST_WALLET_BALANCES_ID=$(deploy list-wallet-balances functions/list-wallet-balances/)
UPDATE_WALLET_ID=$(deploy update-wallet              functions/update-wallet/)
ARCHIVE_WALLET_ID=$(deploy archive-wallet            functions/archive-wallet/)
WALLET_LEDGER_ID=$(deploy wallet-ledger              functions/wallet-ledger/)
WALLET_TOPUP_ID=$(deploy wallet-top-up               functions/wallet-top-up/)

echo ""
echo "Function IDs (copy into instal-api.yaml manually where needed):"
echo "  create-wallet:        $CREATE_WALLET_ID"
echo "  list-wallets:         $LIST_WALLETS_ID"
echo "  get-wallet:           $GET_WALLET_ID"
echo "  get-wallet-balance:   $GET_WALLET_BALANCE_ID"
echo "  list-wallet-balances: $LIST_WALLET_BALANCES_ID"
echo "  update-wallet:        $UPDATE_WALLET_ID"
echo "  archive-wallet:       $ARCHIVE_WALLET_ID"
echo "  wallet-ledger:        $WALLET_LEDGER_ID"
echo "  wallet-top-up:        $WALLET_TOPUP_ID"
echo ""
echo "Done. Update instal-api.yaml manually with any new IDs and deploy the API Gateway separately."
