#!/usr/bin/env bash

# WhatsApp Functions Environment Configuration
# This file contains environment variables specific to WhatsApp reminder functionality

# Base environment (inherit from deploy_env.sh)
source deploy_env.sh

# WhatsApp-specific environment variables
export GREEN_API_BASE_URL="https://api.green-api.com"
export WHATSAPP_RATE_LIMIT_PER_MINUTE=30
export WHATSAPP_MAX_RETRY_ATTEMPTS=3
export WHATSAPP_RETRY_DELAY_SECONDS=2

# Cron schedule for automatic reminders (9:00 AM UTC daily)
export AUTO_REMINDER_CRON_SCHEDULE="0 9 * * *"

# Function memory and timeout configurations
export WHATSAPP_SETTINGS_MEMORY="256m"
export WHATSAPP_SETTINGS_TIMEOUT="20s"
export WHATSAPP_REMINDER_MEMORY="1024m"
export WHATSAPP_REMINDER_TIMEOUT="300s"

# Logging configuration
export WHATSAPP_LOG_LEVEL="INFO"
export WHATSAPP_ENABLE_DEBUG_LOGS="false"

echo "WhatsApp environment variables loaded:"
echo "  GREEN_API_BASE_URL: $GREEN_API_BASE_URL"
echo "  WHATSAPP_RATE_LIMIT_PER_MINUTE: $WHATSAPP_RATE_LIMIT_PER_MINUTE"
echo "  AUTO_REMINDER_CRON_SCHEDULE: $AUTO_REMINDER_CRON_SCHEDULE"
echo "  WHATSAPP_SETTINGS_MEMORY: $WHATSAPP_SETTINGS_MEMORY"
echo "  WHATSAPP_REMINDER_MEMORY: $WHATSAPP_REMINDER_MEMORY"