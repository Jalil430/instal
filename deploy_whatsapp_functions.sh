#!/bin/bash

echo "📱 Deploying WhatsApp Reminder Functions to Yandex Cloud..."

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
            --description="WhatsApp reminder function: ${func_name}"; then
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
        echo "${func_name}=${function_id}" >> function_ids.txt
        
        rm -rf "${func_path}/shared" # CLEANUP
        return 0
    else
        echo -e "${RED}❌ Failed to deploy ${func_name}${NC}"
        rm -rf "${func_path}/shared" # CLEANUP
        return 1
    fi
}

# Function to create cron trigger
create_cron_trigger() {
    local trigger_name=$1
    local function_name=$2
    local cron_expression=$3
    local description=$4
    
    echo -e "${BLUE}⏰ Creating cron trigger: ${trigger_name}...${NC}"
    
    if yc serverless trigger create timer \
        --name=${trigger_name} \
        --cron-expression="${cron_expression}" \
        --invoke-function-name=${function_name} \
        --invoke-function-service-account-id=aje6aqidkl72tp8qttce \
        --description="${description}"; then
        echo -e "${GREEN}✅ Cron trigger ${trigger_name} created successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create cron trigger ${trigger_name}${NC}"
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
    sed -i.bak "/^${FUNC_TO_DEPLOY}=/d" function_ids.txt
    rm function_ids.txt.bak

    case ${FUNC_TO_DEPLOY} in
        "get-whatsapp-settings")
            deploy_function "get-whatsapp-settings" "functions/get-whatsapp-settings/" "256m" "15s" || exit 1
            ;;
        "update-whatsapp-settings")
            deploy_function "update-whatsapp-settings" "functions/update-whatsapp-settings/" "256m" "20s" || exit 1
            ;;
        "test-whatsapp-connection")
            deploy_function "test-whatsapp-connection" "functions/test-whatsapp-connection/" "256m" "30s" || exit 1
            ;;
        "send-manual-reminder")
            deploy_function "send-manual-reminder" "functions/send-manual-reminder/" "1024m" "60s" || exit 1
            ;;
        "send-auto-reminders")
            deploy_function "send-auto-reminders" "functions/send-auto-reminders/" "1024m" "300s" || exit 1
            ;;
        *)
            echo -e "${RED}❌ Unknown function specified: '${FUNC_TO_DEPLOY}'. Available functions: get-whatsapp-settings, update-whatsapp-settings, test-whatsapp-connection, send-manual-reminder, send-auto-reminders${NC}"
            exit 1
            ;;
    esac
    echo -e "\n${GREEN}✅ Deployment of ${FUNC_TO_DEPLOY} complete!${NC}"
else
    # Deploy all functions
    echo -e "${YELLOW}📋 WhatsApp Functions to be deployed:${NC}"
    echo "   📱 WhatsApp Settings Functions (3)"
    echo "   📨 WhatsApp Reminder Functions (2)"
    echo "   ⏰ Cron Triggers (1)"

    # Clear previous function IDs
    > function_ids.txt

    echo -e "\n${BLUE}📱 Deploying WhatsApp Settings Functions...${NC}"

    # Deploy WhatsApp settings functions
    deploy_function "get-whatsapp-settings" "functions/get-whatsapp-settings/" "256m" "15s" || exit 1
    deploy_function "update-whatsapp-settings" "functions/update-whatsapp-settings/" "256m" "20s" || exit 1
    deploy_function "test-whatsapp-connection" "functions/test-whatsapp-connection/" "256m" "30s" || exit 1

    echo -e "\n${BLUE}📨 Deploying WhatsApp Reminder Functions...${NC}"

    # Deploy reminder functions with higher memory and timeout for batch processing
    deploy_function "send-manual-reminder" "functions/send-manual-reminder/" "1024m" "60s" || exit 1
    deploy_function "send-auto-reminders" "functions/send-auto-reminders/" "1024m" "300s" || exit 1

    # Comment out cron trigger creation for now
    # echo -e "\n${BLUE}⏰ Setting up Cron Triggers...${NC}"
    # Create cron trigger for automatic reminders (daily at 9:00 AM UTC)
    # create_cron_trigger "whatsapp-auto-reminders-trigger" "send-auto-reminders" "0 0 9 * * ?" "Daily WhatsApp reminder trigger at 9:00 AM UTC" || exit 1
fi

echo -e "\n${GREEN}🎉 All WhatsApp functions deployed successfully!${NC}"

echo -e "\n${YELLOW}📝 Function IDs for API Gateway:${NC}"
if [ -f function_ids.txt ]; then
    cat function_ids.txt
    echo -e "\n${BLUE}💡 Update instal-api.yaml with these function IDs${NC}"
else
    echo -e "${RED}❌ Function IDs file not found${NC}"
fi

echo -e "\n${YELLOW}📝 Next Steps:${NC}"
echo "1. Update instal-api.yaml with the function IDs above"
echo "2. Deploy the updated API Gateway configuration"
echo "3. Test WhatsApp settings and reminder functionality"
echo "4. Verify cron trigger is working (check logs after 9:00 AM UTC)"

echo -e "\n${BLUE}🔗 WhatsApp Endpoints:${NC}"
echo "   GET /whatsapp/settings - Get WhatsApp settings"
echo "   PUT /whatsapp/settings - Update WhatsApp settings"
echo "   POST /whatsapp/test-connection - Test WhatsApp connection"
echo "   POST /whatsapp/send-manual-reminder - Send manual reminders"

echo -e "\n${BLUE}⏰ Cron Schedule:${NC}"
echo "   Daily at 9:00 AM UTC - Automatic reminder processing"

echo -e "\n${GREEN}✨ WhatsApp Deployment Complete!${NC}"