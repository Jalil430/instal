#!/bin/bash

# YDB CLI Setup Script for Instal Application Database Optimization
# Make sure you have YDB CLI installed: https://ydb.tech/en/docs/reference/ydb-cli/install

# Set your YDB connection parameters
export YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"
export YDB_DATABASE="/ru-central1/b1gf1hpknipc1oe40ebv/etni7p01mkofdmh58rp3"
export SERVICE_ACCOUNT_ID="aje6aqidkl72tp8qttce"

echo "YDB CLI Setup for Instal Application"
echo "===================================="
echo "Endpoint: $YDB_ENDPOINT"
echo "Database: $YDB_DATABASE"
echo "Service Account ID: $SERVICE_ACCOUNT_ID"
echo ""

# Check if YDB CLI is installed
if ! command -v ydb &> /dev/null; then
    echo "❌ YDB CLI is not installed. Please install it first:"
    echo "https://ydb.tech/en/docs/reference/ydb-cli/install"
    exit 1
fi

# Update YDB CLI if needed
echo "Checking YDB CLI version..."
ydb version --disable-checks

echo ""
echo "Testing YDB connection with service account..."

# Try to authenticate and connect using service account ID
if ydb -e "$YDB_ENDPOINT" -d "$YDB_DATABASE" --sa-id "$SERVICE_ACCOUNT_ID" scheme ls; then
    echo ""
    echo "✅ YDB CLI setup complete!"
    echo "✅ Connection successful!"
    echo ""
    echo "You can now run the database optimization:"
    echo "./execute_optimization.sh"
else
    echo ""
    echo "❌ Connection failed. This could be due to:"
    echo "1. Network/DNS issues"
    echo "2. Service account doesn't have proper permissions"
    echo "3. Incorrect endpoint, database path, or service account ID"
    echo ""
    echo "Make sure:"
    echo "- Service account $SERVICE_ACCOUNT_ID has YDB admin permissions"
    echo "- You have network access to ydb.serverless.yandexcloud.net"
    echo "- The database path is correct"
    echo ""
    echo "Alternative: Run queries manually using Yandex Cloud Console"
    exit 1
fi