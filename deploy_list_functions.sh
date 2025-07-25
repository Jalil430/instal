#!/bin/bash

echo "📋 Deploying List Functions to Yandex Cloud..."

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
    local memory=${3:-512m}
    local timeout=${4:-30s}
    
    echo -e "${BLUE}📦 Deploying ${func_name}...${NC}"
    
    # First, check if function exists, if not create it
    if ! yc serverless function get ${func_name} >/dev/null 2>&1; then
        echo -e "${YELLOW}📋 Function ${func_name} doesn't exist, creating it...${NC}"
        if ! yc serverless function create \
            --name=${func_name} \
            --description="List function: ${func_name}"; then
            echo -e "${RED}❌ Failed to create function ${func_name}${NC}"
            return 1
        fi
        echo -e "${GREEN}✅ Function ${func_name} created successfully${NC}"
    fi
    
    # Now deploy the version
    if yc serverless function version create \
        --function-name=${func_name} \
        --runtime=python39 \
        --entrypoint=index.handler \
        --memory=${memory} \
        --execution-timeout=${timeout} \
        --service-account-id aje6aqidkl72tp8qttce \
        --source-path=${func_path} \
        --environment API_KEY=${API_KEY},JWT_SECRET_KEY=${JWT_SECRET_KEY},YDB_ENDPOINT=${YDB_ENDPOINT},YDB_DATABASE=${YDB_DATABASE}; then
        echo -e "${GREEN}✅ ${func_name} deployed successfully${NC}"
        
        # Get function ID for API Gateway configuration
        local function_id=$(yc serverless function get ${func_name} --format json | jq -r '.id')
        echo -e "${BLUE}📋 Function ID: ${function_id}${NC}"
        echo "${func_name}=${function_id}" >> list_function_ids.txt
        
        rm -rf "${func_path}/shared" # CLEANUP
        return 0
    else
        echo -e "${RED}❌ Failed to deploy ${func_name}${NC}"
        rm -rf "${func_path}/shared" # CLEANUP
        return 1
    fi
}

# Load environment variables automatically
if [ -f "deploy_env.sh" ]; then
    echo -e "${BLUE}📋 Loading environment variables from deploy_env.sh...${NC}"
    source deploy_env.sh
else
    echo -e "${YELLOW}⚠️  deploy_env.sh not found. Using manual environment variables.${NC}"
    # Set default environment variables if not provided
    export YDB_ENDPOINT=${YDB_ENDPOINT:-"grpcs://ydb.serverless.yandexcloud.net:2135"}
    export YDB_DATABASE=${YDB_DATABASE:-"/ru-central1/b1gf1hpknipc1oe40ebv/etni7p01mkofdmh58rp3"}
fi

# Check required environment variables
if [ -z "$JWT_SECRET_KEY" ] || [ "$JWT_SECRET_KEY" = "your-secure-jwt-secret-key-here-change-this" ]; then
    echo -e "${RED}❌ Error: JWT_SECRET_KEY is not set or using default value.${NC}"
    echo -e "${YELLOW}💡 Please update JWT_SECRET_KEY in deploy_env.sh with a secure random key.${NC}"
    exit 1
fi
if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ Error: API_KEY is not set. Please check deploy_env.sh.${NC}"
    exit 1
fi

echo -e "${BLUE}🔧 Configuration:${NC}"
echo "   API_KEY: ${API_KEY:0:10}..."
echo "   JWT_SECRET_KEY: ${JWT_SECRET_KEY:0:20}..."
echo "   YDB_ENDPOINT: $YDB_ENDPOINT"
echo "   YDB_DATABASE: $YDB_DATABASE"

# Main deployment logic
if [ -n "$1" ]; then
    # Deploy a single specified function
    FUNC_TO_DEPLOY=$1
    echo -e "${BLUE}🎯 Deploying single function: ${FUNC_TO_DEPLOY}${NC}"

    # Clear previous function ID for this function to avoid duplicates
    # Note: this uses a temporary file and mv for macOS compatibility with sed -i
    sed -i.bak "/^${FUNC_TO_DEPLOY}=/d" list_function_ids.txt 2>/dev/null || true
    rm -f list_function_ids.txt.bak

    case ${FUNC_TO_DEPLOY} in
        "list-installments")
            deploy_function "list-installments" "functions/list-installments/" "512m" "30s" || exit 1
            ;;
        "list-clients")
            deploy_function "list-clients" "functions/list-clients/" "512m" "30s" || exit 1
            ;;
        "list-investors")
            deploy_function "list-investors" "functions/list-investors/" "512m" "30s" || exit 1
            ;;
        *)
            echo -e "${RED}❌ Unknown function specified: '${FUNC_TO_DEPLOY}'. Available functions: list-installments, list-clients, list-investors${NC}"
            exit 1
            ;;
    esac
    echo -e "\n${GREEN}✅ Deployment of ${FUNC_TO_DEPLOY} complete!${NC}"
else
    # Deploy all functions
    echo -e "${YELLOW}📋 List Functions to be deployed:${NC}"
    echo "   📋 list-installments - List all installments with pagination (updated limit: 50,000)"
    echo "   👥 list-clients - List all clients with pagination (updated limit: 50,000)"
    echo "   💼 list-investors - List all investors with pagination (updated limit: 50,000)"

    # Clear previous function IDs
    > list_function_ids.txt

    echo -e "\n${BLUE}📋 Deploying List Functions with Updated Pagination Limits...${NC}"

    # Deploy list functions with sufficient memory and timeout for large datasets
    deploy_function "list-installments" "functions/list-installments/" "512m" "30s" || exit 1
    deploy_function "list-clients" "functions/list-clients/" "512m" "30s" || exit 1
    deploy_function "list-investors" "functions/list-investors/" "512m" "30s" || exit 1
fi

echo -e "\n${GREEN}🎉 All list functions deployed successfully!${NC}"

echo -e "\n${YELLOW}📝 Function IDs for API Gateway:${NC}"
if [ -f list_function_ids.txt ]; then
    cat list_function_ids.txt
    echo -e "\n${BLUE}💡 Update instal-api.yaml with these function IDs if needed${NC}"
else
    echo -e "${RED}❌ Function IDs file not found${NC}"
fi

echo -e "\n${YELLOW}📝 What was updated:${NC}"
echo "✅ Backend functions now support up to 50,000 items per request"
echo "✅ Frontend now requests 20,000 items by default"
echo "✅ Pagination limits increased from 100 to 50,000"

echo -e "\n${YELLOW}📝 Next Steps:${NC}"
echo "1. Test the installments list screen - it should now load all installments"
echo "2. Test the clients list screen - it should now load all clients"
echo "3. Test the investors list screen - it should now load all investors"
echo "4. Monitor function performance with larger datasets"

echo -e "\n${BLUE}🔗 Updated Endpoints:${NC}"
echo "   GET /installments?user_id=X&limit=20000&offset=0 - List installments"
echo "   GET /clients?user_id=X&limit=20000&offset=0 - List clients"
echo "   GET /investors?user_id=X&limit=20000&offset=0 - List investors"

echo -e "\n${BLUE}📊 Performance Notes:${NC}"
echo "   • Functions allocated 512MB memory for handling large datasets"
echo "   • 30-second timeout to accommodate database queries"
echo "   • Caching enabled on frontend to improve subsequent loads"

echo -e "\n${GREEN}✨ List Functions Deployment Complete!${NC}"
echo -e "${YELLOW}🔄 Don't forget to restart your Flutter app to pick up the frontend changes!${NC}"