#!/bin/bash

echo "Deploying functions..."

echo "Deploying auth-refresh function..."
yc serverless function version create \
  --function-name=auth-refresh \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/auth-refresh/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Deploying auth-register function..."
yc serverless function version create \
  --function-name=auth-register \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/auth-register/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

  echo "Deploying auth-login function..."
yc serverless function version create \
  --function-name=auth-login \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/auth-login/ \
  --environment API_KEY="$API_KEY" \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "All functions deployed successfully!"