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

echo "Starting deployment (focused mode)."
echo "Tip: source deploy_env.sh before running this script."

# Create functions if they don't exist yet
# ensure_function create-installment
# ensure_function create-wallet
# ensure_function update-installment-payment
# ensure_function allocate-installment
# ensure_function void-installment-allocation
# ensure_function get-installment
# ensure_function delete-installment
# ensure_function get-wallet
# ensure_function delete-wallet
ensure_function wallet-withdraw
ensure_function wallet-top-up


# Deploy only the functions we updated
# CREATE_INSTALLMENT_ID=$(deploy create-installment           functions/create-installment/)
# CREATE_WALLET_ID=$(deploy create-wallet                     functions/create-wallet/)
# UPDATE_INSTALLMENT_PAYMENT_ID=$(deploy update-installment-payment functions/update-installment-payment/)
# ALLOCATE_INSTALLMENT_ID=$(deploy allocate-installment        functions/allocate-installment/)
# VOID_INSTALLMENT_ALLOCATION_ID=$(deploy void-installment-allocation functions/void-installment-allocation/)
# GET_INSTALLMENT_ID=$(deploy get-installment                 functions/get-installment/)
# DELETE_INSTALLMENT_ID=$(deploy delete-installment               functions/delete-installment/)
# GET_WALLET_ID=$(deploy get-wallet                             functions/get-wallet/)
# GET_WALLET_ID=$(deploy update-wallet                             functions/update-wallet/)
# GET_WALLET_ID=$(deploy delete-wallet                             functions/delete-wallet/)
GET_WALLET_ID=$(deploy wallet-withdraw                             functions/wallet-withdraw/)
GET_WALLET_ID=$(deploy wallet-top-up                             functions/wallet-top-up/)

echo ""
echo "Function IDs (copy into instal-api.yaml where needed):"
# echo "  create-installment:            $CREATE_INSTALLMENT_ID"
# echo "  create-wallet:                 $CREATE_WALLET_ID"
# echo "  update-installment-payment:    $UPDATE_INSTALLMENT_PAYMENT_ID"
# echo "  allocate-installment:          $ALLOCATE_INSTALLMENT_ID"
# echo "  void-installment-allocation:   $VOID_INSTALLMENT_ALLOCATION_ID"
# echo "  get-installment:               $GET_INSTALLMENT_ID"
# echo "  delete-installment:               $DELETE_INSTALLMENT_ID"
# echo "  get-wallet:               $GET_WALLET_ID"
# echo "  update-wallet:               $GET_WALLET_ID"
# echo "  delete-wallet:               $GET_WALLET_ID"
echo "  wallet-withdraw:               $GET_WALLET_ID"
echo "  wallet-top-up:               $GET_WALLET_ID"
echo ""
echo "Done."
