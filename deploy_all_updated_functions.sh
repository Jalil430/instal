#!/bin/bash

echo "🚀 Deploying all JWT-authenticated functions to Yandex Cloud..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to deploy and check status
deploy_function() {
    local func_name=$1
    local func_path=$2
    
    echo -e "${BLUE}📦 Deploying ${func_name}...${NC}"
    
    if yc serverless function version create \
        --function-name=${func_name} \
        --runtime=python39 \
        --entrypoint=index.handler \
        --memory=512m \
        --execution-timeout=30s \
        --service-account-id aje6aqidkl72tp8qttce \
        --source-path=${func_path} \
        --environment API_KEY=${API_KEY},JWT_SECRET_KEY=${JWT_SECRET_KEY},YDB_ENDPOINT=${YDB_ENDPOINT},YDB_DATABASE=${YDB_DATABASE}; then
        echo -e "${GREEN}✅ ${func_name} deployed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to deploy ${func_name}${NC}"
        return 1
    fi
}

# Set default environment variables if not provided
export YDB_ENDPOINT=${YDB_ENDPOINT:-"grpcs://ydb.serverless.yandexcloud.net:2135"}
export YDB_DATABASE=${YDB_DATABASE:-"/ru-central1/b1gf1hpknipc1oe40ebv/etni7p01mkofdmh58rp3"}

# Check required environment variables
if [ -z "$JWT_SECRET_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: JWT_SECRET_KEY not set. Using default.${NC}"
fi
if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ Error: API_KEY is not set. Please export it before deploying.${NC}"
    exit 1
fi

echo -e "${BLUE}🔧 Configuration:${NC}"
echo "   API_KEY: ${API_KEY:0:10}..."
echo "   JWT_SECRET_KEY: ${JWT_SECRET_KEY:0:20}..."
echo "   YDB_ENDPOINT: $YDB_ENDPOINT"
echo "   YDB_DATABASE: $YDB_DATABASE"

echo -e "${YELLOW}📋 Functions to be deployed:${NC}"
echo "   🔐 Authentication Functions (4)"
echo "   👤 Client Functions (6)"  
echo "   💰 Investor Functions (6)"
echo "   📋 Installment Functions (6)"
echo "   🔍 Search Functions (3)"

echo -e "\n${BLUE}🔐 Deploying Authentication Functions...${NC}"
deploy_function "auth-register" "functions/auth-register/" || exit 1
deploy_function "auth-login" "functions/auth-login/" || exit 1
deploy_function "auth-refresh" "functions/auth-refresh/" || exit 1
deploy_function "auth-verify" "functions/auth-verify/" || exit 1

echo -e "\n${BLUE}👤 Deploying Client Functions...${NC}"
deploy_function "create-client" "functions/create-client/" || exit 1
deploy_function "list-clients" "functions/list-clients/" || exit 1
deploy_function "get-client" "functions/get-client/" || exit 1
deploy_function "update-client" "functions/update-client/" || exit 1
deploy_function "delete-client" "functions/delete-client/" || exit 1
deploy_function "search-clients" "functions/search-clients/" || exit 1

echo -e "\n${BLUE}💰 Deploying Investor Functions...${NC}"
deploy_function "create-investor" "functions/create-investor/" || exit 1
deploy_function "list-investors" "functions/list-investors/" || exit 1
deploy_function "get-investor" "functions/get-investor/" || exit 1
deploy_function "update-investor" "functions/update-investor/" || exit 1
deploy_function "delete-investor" "functions/delete-investor/" || exit 1
deploy_function "search-investors" "functions/search-investors/" || exit 1

echo -e "\n${BLUE}📋 Deploying Installment Functions...${NC}"
deploy_function "create-installment" "functions/create-installment/" || exit 1
deploy_function "list-installments" "functions/list-installments/" || exit 1
deploy_function "get-installment" "functions/get-installment/" || exit 1
deploy_function "delete-installment" "functions/delete-installment/" || exit 1
deploy_function "search-installments" "functions/search-installments/" || exit 1
deploy_function "update-installment-payment" "functions/update-installment-payment/" || exit 1

echo -e "\n${GREEN}🎉 All functions deployed successfully!${NC}"

echo -e "\n${YELLOW}📝 Next Steps:${NC}"
echo "1. Verify all endpoints in the API Gateway."
echo "2. Test the full application flow."

echo -e "\n${BLUE}🔗 Main Endpoints:${NC}"
echo "   POST /auth/login - Login user" 
echo "   GET /clients - List clients"
echo "   GET /investors - List investors"
echo "   GET /installments - List installments"

echo -e "\n${GREEN}✨ Full Deployment Complete!${NC}" 