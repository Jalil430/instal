#!/bin/bash

echo "Deploying subscription functions..."

echo "Deploying validate-subscription-code function..."
yc serverless function version create \
  --function-name=validate-subscription-code \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=128m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/validate-subscription-code/ \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Deploying check-subscription-status function..."
yc serverless function version create \
  --function-name=check-subscription-status \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=128m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/check-subscription-status/ \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Subscription functions deployed successfully!"