# WhatsApp Reminders Deployment Guide

This guide covers the deployment of WhatsApp reminder functionality to Yandex Cloud.

## Prerequisites

1. **Yandex Cloud CLI** installed and configured
2. **Environment variables** set up (see `deploy_env.sh`)
3. **Service account** with appropriate permissions
4. **Green API account** for WhatsApp messaging

## Deployment Steps

### 1. Set Environment Variables

```bash
# Load base environment
source deploy_env.sh

# Load WhatsApp-specific environment
source whatsapp_env.sh
```

### 2. Deploy WhatsApp Functions

```bash
# Deploy all WhatsApp functions
chmod +x deploy_whatsapp_functions.sh
./deploy_whatsapp_functions.sh
```

This will deploy:
- `get-whatsapp-settings` - Retrieve user WhatsApp settings
- `update-whatsapp-settings` - Update WhatsApp settings and credentials
- `test-whatsapp-connection` - Test Green API connection
- `send-manual-reminder` - Send manual reminders from frontend
- `send-auto-reminders` - Process automatic daily reminders

### 3. Set Up Cron Trigger

The deployment script automatically creates a cron trigger:
- **Name**: `whatsapp-auto-reminders-trigger`
- **Schedule**: Daily at 9:00 AM UTC (`0 9 * * *`)
- **Function**: `send-auto-reminders`

### 4. Update API Gateway

1. Copy function IDs from deployment output
2. Update `instal-api.yaml` with actual function IDs:

```yaml
# Replace placeholders with actual function IDs
function_id: PLACEHOLDER_GET_WHATSAPP_SETTINGS     # -> actual function ID
function_id: PLACEHOLDER_UPDATE_WHATSAPP_SETTINGS  # -> actual function ID
function_id: PLACEHOLDER_TEST_WHATSAPP_CONNECTION  # -> actual function ID
function_id: PLACEHOLDER_SEND_MANUAL_REMINDER      # -> actual function ID
```

3. Deploy updated API Gateway configuration:

```bash
yc serverless api-gateway update --name instal-api --spec instal-api.yaml
```

## Function Configurations

### Memory and Timeout Settings

| Function | Memory | Timeout | Purpose |
|----------|--------|---------|---------|
| get-whatsapp-settings | 256MB | 15s | Lightweight settings retrieval |
| update-whatsapp-settings | 256MB | 20s | Settings update with validation |
| test-whatsapp-connection | 256MB | 30s | Connection testing with retries |
| send-manual-reminder | 1024MB | 60s | Batch manual reminder processing |
| send-auto-reminders | 1024MB | 300s | Daily batch processing |

### Environment Variables

All functions receive these environment variables:
- `API_KEY` - Yandex Cloud API key
- `JWT_SECRET_KEY` - JWT token signing key
- `YDB_ENDPOINT` - Database connection endpoint
- `YDB_DATABASE` - Database path

## Database Setup

The WhatsApp functionality requires a `whatsapp_settings` table:

```sql
CREATE TABLE whatsapp_settings (
    user_id Utf8 NOT NULL,
    green_api_instance_id Utf8,
    green_api_token Utf8,
    reminder_template_7_days Utf8,
    reminder_template_due_today Utf8,
    reminder_template_manual Utf8,
    is_enabled Bool DEFAULT false,
    created_at Timestamp,
    updated_at Timestamp,
    PRIMARY KEY (user_id)
);
```

## Testing Deployment

### 1. Test API Endpoints

```bash
# Test settings endpoint
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://your-api-gateway-url/whatsapp/settings

# Test connection
curl -X POST \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"green_api_instance_id":"YOUR_ID","green_api_token":"YOUR_TOKEN"}' \
     https://your-api-gateway-url/whatsapp/test-connection
```

### 2. Test Manual Reminders

```bash
# Send manual reminder
curl -X POST \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"installment_ids":["installment-id"],"template_type":"manual"}' \
     https://your-api-gateway-url/whatsapp/send-manual-reminder
```

### 3. Verify Cron Trigger

Check function logs after 9:00 AM UTC to verify automatic reminders:

```bash
yc serverless function logs send-auto-reminders
```

## Monitoring and Logs

### Function Logs

```bash
# View logs for specific function
yc serverless function logs FUNCTION_NAME

# View logs with timestamps
yc serverless function logs FUNCTION_NAME --since 1h
```

### Trigger Logs

```bash
# View trigger execution logs
yc serverless trigger logs whatsapp-auto-reminders-trigger
```

## Troubleshooting

### Common Issues

1. **Function timeout**: Increase timeout for batch operations
2. **Memory limit**: Increase memory for large batch processing
3. **Rate limiting**: Check Green API rate limits and delays
4. **Authentication**: Verify JWT tokens and API keys
5. **Database connection**: Check YDB endpoint and credentials

### Debug Mode

Enable debug logging by setting environment variable:
```bash
export WHATSAPP_ENABLE_DEBUG_LOGS="true"
```

## Security Considerations

1. **Credentials**: Green API tokens are encrypted in database
2. **Phone numbers**: Masked in logs for privacy
3. **Rate limiting**: Built-in rate limiting for Green API
4. **Authentication**: All endpoints require JWT authentication
5. **Input validation**: Request validation and sanitization

## Maintenance

### Regular Tasks

1. **Monitor logs** for errors and performance
2. **Check cron trigger** execution daily
3. **Update Green API credentials** as needed
4. **Monitor rate limits** and usage
5. **Review error rates** and retry patterns

### Updates

To update functions:
1. Modify function code
2. Run deployment script
3. Test functionality
4. Monitor for issues

## Support

For issues with:
- **Yandex Cloud**: Check Yandex Cloud documentation
- **Green API**: Check Green API documentation
- **WhatsApp**: Verify phone number formats and message content
- **Database**: Check YDB connection and table structure