#!/bin/bash

echo "Deploying analytics function..."

echo "Deploying get-analytics-optimized function..."
yc serverless function version create \
  --function-name=analytics-optimized \
  --runtime=python39 \
  --entrypoint=index.handler \
  --memory=512m \
  --execution-timeout=30s \
  --service-account-id=aje6aqidkl72tp8qttce \
  --source-path=functions/get-analytics-optimized/ \
  --environment JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --environment YDB_ENDPOINT="$YDB_ENDPOINT" \
  --environment YDB_DATABASE="$YDB_DATABASE"

echo "Analytics function deployed successfully!"