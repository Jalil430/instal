#!/bin/bash

# Deploy the updated create-installment, update-client, and update-investor functions
echo "Deploying updated functions..."

echo "Deploying create-installment function..."
yc serverless function version create \
  --function-name=create-installment \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/create-installment/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Deploying update-client function..."
yc serverless function version create \
  --function-name=update-client \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/update-client/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Deploying update-investor function..."
yc serverless function version create \
  --function-name=update-investor \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/update-investor/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Deploying update-installment-payment function..."
yc serverless function version create \
  --function-name=update-installment-payment \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/update-installment-payment/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "All functions deployed successfully!"