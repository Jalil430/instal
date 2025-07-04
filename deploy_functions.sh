#!/bin/bash

# Source environment variables
if [ -f deploy_env.sh ]; then
    source deploy_env.sh
fi

# Set service account ID
export SERVICE_ACCOUNT_ID="aje6aqidkl72tp8qttce"

# Function to deploy a single function
deploy_function() {
    local func_name=$1
    echo "Deploying $func_name..."
    
    cd functions/$func_name
    zip -r ${func_name}-fixed.zip . >/dev/null 2>&1
    mv ${func_name}-fixed.zip ../..
    cd ../..
    
    yc serverless function version create \
        --function-name $func_name \
        --runtime python39 \
        --entrypoint index.handler \
        --memory 128m \
        --execution-timeout 5s \
        --source-path ${func_name}-fixed.zip \
        --service-account-id $SERVICE_ACCOUNT_ID \
        --environment API_KEY=$API_KEY,YDB_ENDPOINT=$YDB_ENDPOINT,YDB_DATABASE=$YDB_DATABASE \
        >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ $func_name deployed successfully"
        rm ${func_name}-fixed.zip
    else
        echo "❌ $func_name deployment failed"
    fi
}

# Check if a specific function name was provided
if [ "$1" ]; then
    echo "Deploying single function: $1"
    deploy_function "$1"
else
    # Deploy all functions
    echo "Deploying all functions..."
    
    # Client functions
    echo "Deploying client functions..."
    deploy_function "create-client"
    deploy_function "get-client"
    deploy_function "update-client"
    deploy_function "delete-client"
    deploy_function "list-clients"
    deploy_function "search-clients"
    
    # Installment functions
    echo "Deploying installment functions..."
    deploy_function "create-installment"
    deploy_function "get-installment"
    deploy_function "update-installment-payment"
    deploy_function "delete-installment"
    deploy_function "list-installments"
    deploy_function "search-installments"
    
    # Investor functions
    echo "Deploying investor functions..."
    deploy_function "create-investor"
    deploy_function "get-investor"
    deploy_function "update-investor"
    deploy_function "delete-investor"
    deploy_function "list-investors"
    deploy_function "search-investors"
fi

echo "Deployment complete!" 