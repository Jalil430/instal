import os
import sys
import json
import logging
from typing import Dict, Any, Optional

# Add shared modules to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database_utils import WhatsAppSettingsRepository
from jwt_auth import JWTAuth
from whatsapp_service import MessageTemplateProcessor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def handler(event, context):
    """
    Yandex Cloud Function handler to get WhatsApp settings for authenticated user
    
    GET /whatsapp/settings
    
    Returns user's WhatsApp settings with masked credentials for security
    """
    try:
        logger.info(f"Get WhatsApp settings request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # Get user's WhatsApp settings
        settings_repo = WhatsAppSettingsRepository()
        user_settings = settings_repo.get_settings(user_id)
        
        if not user_settings:
            # Return default settings if none exist
            logger.info(f"No WhatsApp settings found for user {user_id}, returning defaults")
            default_settings = create_default_settings(user_id)
            
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(default_settings)
            }
        
        # Mask sensitive credentials for security
        masked_settings = mask_sensitive_data(user_settings)
        
        logger.info(f"WhatsApp settings retrieved for user {user_id}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(masked_settings)
        }
        
    except Exception as e:
        logger.error(f"Failed to get WhatsApp settings: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Failed to retrieve WhatsApp settings',
                'message': str(e)
            })
        }

def create_default_settings(user_id: str) -> Dict[str, Any]:
    """
    Create default WhatsApp settings for a new user
    
    Args:
        user_id: User ID
        
    Returns:
        Default settings dictionary
    """
    return {
        'user_id': user_id,
        'green_api_instance_id': '',
        'green_api_token': '',
        'reminder_template_7_days': MessageTemplateProcessor.DEFAULT_TEMPLATES['reminder_7_days'],
        'reminder_template_due_today': MessageTemplateProcessor.DEFAULT_TEMPLATES['reminder_due_today'],
        'reminder_template_manual': MessageTemplateProcessor.DEFAULT_TEMPLATES['reminder_manual'],
        'is_enabled': False,
        'created_at': None,
        'updated_at': None,
        'is_configured': False,
        'connection_status': 'not_configured'
    }

def mask_sensitive_data(settings: Dict[str, Any]) -> Dict[str, Any]:
    """
    Mask sensitive credentials in settings for security
    
    Args:
        settings: Raw settings from database
        
    Returns:
        Settings with masked credentials
    """
    masked = settings.copy()
    
    # Mask Green API credentials
    if masked.get('green_api_instance_id'):
        instance_id = masked['green_api_instance_id']
        if len(instance_id) > 8:
            masked['green_api_instance_id'] = instance_id[:4] + '*' * (len(instance_id) - 8) + instance_id[-4:]
        else:
            masked['green_api_instance_id'] = '*' * len(instance_id)
    
    if masked.get('green_api_token'):
        token = masked['green_api_token']
        if len(token) > 8:
            masked['green_api_token'] = token[:4] + '*' * (len(token) - 8) + token[-4:]
        else:
            masked['green_api_token'] = '*' * len(token)
    
    # Add computed fields
    masked['is_configured'] = bool(
        settings.get('green_api_instance_id') and 
        settings.get('green_api_token')
    )
    
    # Add connection status (will be updated by connection test)
    if masked['is_configured']:
        masked['connection_status'] = 'configured'
    else:
        masked['connection_status'] = 'not_configured'
    
    # Format timestamps
    if masked.get('created_at'):
        masked['created_at'] = format_timestamp(masked['created_at'])
    
    if masked.get('updated_at'):
        masked['updated_at'] = format_timestamp(masked['updated_at'])
    
    return masked

def format_timestamp(timestamp) -> str:
    """
    Format timestamp for API response
    
    Args:
        timestamp: Timestamp object
        
    Returns:
        Formatted timestamp string
    """
    try:
        if hasattr(timestamp, 'isoformat'):
            return timestamp.isoformat()
        elif hasattr(timestamp, 'strftime'):
            return timestamp.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
        else:
            return str(timestamp)
    except Exception:
        return str(timestamp)