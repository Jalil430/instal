#!/bin/bash

echo "Creating and deploying wallet functions..."

# Function to create or get function ID
create_function() {
    local FUNCTION_NAME=$1
    local SOURCE_PATH=$2

    echo "Creating/updating $FUNCTION_NAME function..."

    # Try to create the function (will fail if it exists)
    yc serverless function create --name="$FUNCTION_NAME" 2>/dev/null || echo "Function $FUNCTION_NAME already exists"

    # Create the version
    local RESULT=$(yc serverless function version create \
      --function-name="$FUNCTION_NAME" \
      --runtime=python39 \
      --entrypoint=index.handler \
      --memory=128m \
      --execution-timeout=30s \
      --service-account-id=aje6aqidkl72tp8qttce \
      --source-path="$SOURCE_PATH" \
      --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
      --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
      --environment YDB_DATABASE="$YDB_DATABASE" \
      --format json)

    local FUNCTION_ID=$(echo "$RESULT" | jq -r '.function_id')
    echo "$FUNCTION_NAME: $FUNCTION_ID"
    echo "$FUNCTION_ID"
}

# Create all wallet functions
echo "Creating create-wallet function..."
CREATE_WALLET_ID=$(create_function "create-wallet" "create-wallet/")

echo "Creating list-wallets function..."
LIST_WALLETS_ID=$(create_function "list-wallets" "list-wallets/")

echo "Creating get-wallet function..."
GET_WALLET_ID=$(create_function "get-wallet" "get-wallet/")

echo "Creating get-wallet-balance function..."
GET_WALLET_BALANCE_ID=$(create_function "get-wallet-balance" "get-wallet-balance/")

echo "Creating list-wallet-balances function..."
LIST_WALLET_BALANCES_ID=$(create_function "list-wallet-balances" "list-wallet-balances/")

echo "Creating update-wallet function..."
UPDATE_WALLET_ID=$(create_function "update-wallet" "update-wallet/")

echo "Creating archive-wallet function..."
ARCHIVE_WALLET_ID=$(create_function "archive-wallet" "archive-wallet/")

echo "Creating delete-wallet function..."
DELETE_WALLET_ID=$(create_function "delete-wallet" "delete-wallet/")

echo "Creating wallet-ledger function..."
WALLET_LEDGER_ID=$(create_function "wallet-ledger" "wallet-ledger/")

echo "Creating wallet-top-up function..."
WALLET_TOPUP_ID=$(create_function "wallet-top-up" "wallet-top-up/")

echo "Creating wallet-withdraw function..."
WALLET_WITHDRAW_ID=$(create_function "wallet-withdraw" "wallet-withdraw/")

echo ""
echo "Wallet functions deployed successfully!"
echo ""
echo "Function IDs:"
echo "create-wallet: $CREATE_WALLET_ID"
echo "list-wallets: $LIST_WALLETS_ID"
echo "get-wallet: $GET_WALLET_ID"
echo "get-wallet-balance: $GET_WALLET_BALANCE_ID"
echo "list-wallet-balances: $LIST_WALLET_BALANCES_ID"
echo "update-wallet: $UPDATE_WALLET_ID"
echo "archive-wallet: $ARCHIVE_WALLET_ID"
echo "delete-wallet: $DELETE_WALLET_ID"
echo "wallet-ledger: $WALLET_LEDGER_ID"
echo "wallet-top-up: $WALLET_TOPUP_ID"
echo "wallet-withdraw: $WALLET_WITHDRAW_ID"
echo ""
echo "Please update instal-api.yaml with these function IDs:"
echo "- Replace WALLET_CREATE_FUNCTION_ID with: $CREATE_WALLET_ID"
echo "- Replace WALLET_LIST_FUNCTION_ID with: $LIST_WALLETS_ID"
echo "- Replace WALLET_GET_FUNCTION_ID with: $GET_WALLET_ID"
echo "- Replace PLACEHOLDER_GET_WALLET_BALANCE with: $GET_WALLET_BALANCE_ID"
echo "- Replace PLACEHOLDER_LIST_WALLET_BALANCES with: $LIST_WALLET_BALANCES_ID"
echo "- Replace WALLET_UPDATE_FUNCTION_ID with: $UPDATE_WALLET_ID"
echo "- Replace WALLET_ARCHIVE_FUNCTION_ID with: $ARCHIVE_WALLET_ID"
echo "- Replace WALLET_DELETE_FUNCTION_ID with: $DELETE_WALLET_ID"
echo "- Replace WALLET_LEDGER_FUNCTION_ID with: $WALLET_LEDGER_ID"
echo "- Replace WALLET_TOPUP_FUNCTION_ID with: $WALLET_TOPUP_ID"
echo "- Replace WALLET_WITHDRAW_FUNCTION_ID with: $WALLET_WITHDRAW_ID"
