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
    
    Returns user's WhatsApp settings with unmasked credentials
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
        
        # Add computed fields without masking credentials
        processed_settings = add_computed_fields(user_settings)
        
        logger.info(f"WhatsApp settings retrieved for user {user_id}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(processed_settings)
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

def add_computed_fields(settings: Dict[str, Any]) -> Dict[str, Any]:
    """
    Add computed fields to settings without masking credentials
    
    Args:
        settings: Raw settings from database
        
    Returns:
        Settings with computed fields
    """
    processed = settings.copy()
    
    # Add computed fields
    processed['is_configured'] = bool(
        settings.get('green_api_instance_id') and 
        settings.get('green_api_token')
    )
    
    # Add connection status (will be updated by connection test)
    if processed['is_configured']:
        processed['connection_status'] = 'configured'
    else:
        processed['connection_status'] = 'not_configured'
    
    # Format timestamps
    if processed.get('created_at'):
        processed['created_at'] = format_timestamp(processed['created_at'])
    
    if processed.get('updated_at'):
        processed['updated_at'] = format_timestamp(processed['updated_at'])
    
    return processed

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