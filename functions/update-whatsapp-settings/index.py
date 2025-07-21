import os
import sys
import json
import logging
from typing import Dict, Any, List, Tuple

# Add shared modules to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database_utils import WhatsAppSettingsRepository
from jwt_auth import JWTAuth
from whatsapp_service import WhatsAppService, MessageTemplateProcessor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def handler(event, context):
    """
    Yandex Cloud Function handler to update WhatsApp settings for authenticated user
    
    PUT /whatsapp/settings
    
    Request body:
    {
        "green_api_instance_id": "string",
        "green_api_token": "string", 
        "reminder_template_7_days": "string",
        "reminder_template_due_today": "string",
        "reminder_template_manual": "string",
        "is_enabled": boolean,
        "test_connection": boolean  // Optional: test connection after update
    }
    """
    try:
        logger.info(f"Update WhatsApp settings request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # Parse and validate request body
        try:
            raw_body = event.get('body', '{}')
            
            # Handle Base64 encoded body
            try:
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                body = json.loads(raw_body)
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid JSON in request body'})
            }
        
        # Validate and sanitize input
        sanitized_settings, validation_errors = validate_and_sanitize_settings(body)
        
        if validation_errors:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Validation failed',
                    'details': validation_errors
                })
            }
        
        # Test connection if requested and credentials provided
        connection_test_result = None
        test_connection = body.get('test_connection', False)
        
        if test_connection and sanitized_settings.get('green_api_instance_id') and sanitized_settings.get('green_api_token'):
            connection_test_result = test_whatsapp_connection(
                sanitized_settings['green_api_instance_id'],
                sanitized_settings['green_api_token']
            )
            
            # If connection test fails and user wants to enable, prevent enabling
            if not connection_test_result['success'] and sanitized_settings.get('is_enabled'):
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Cannot enable WhatsApp reminders: connection test failed',
                        'connection_test': connection_test_result
                    })
                }
        
        # Save settings to database
        settings_repo = WhatsAppSettingsRepository()
        
        try:
            success = settings_repo.save_settings(user_id, sanitized_settings)
            
            if not success:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Failed to save WhatsApp settings'})
                }
            
        except Exception as e:
            logger.error(f"Database error saving settings for user {user_id}: {e}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database error while saving settings'})
            }
        
        # Prepare response
        response_data = {
            'message': 'WhatsApp settings updated successfully',
            'user_id': user_id,
            'is_enabled': sanitized_settings.get('is_enabled', False),
            'is_configured': bool(sanitized_settings.get('green_api_instance_id') and sanitized_settings.get('green_api_token'))
        }
        
        # Include connection test result if performed
        if connection_test_result:
            response_data['connection_test'] = connection_test_result
        
        logger.info(f"WhatsApp settings updated successfully for user {user_id}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(response_data)
        }
        
    except Exception as e:
        logger.error(f"Failed to update WhatsApp settings: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Failed to update WhatsApp settings',
                'message': str(e)
            })
        }

def validate_and_sanitize_settings(data: Dict[str, Any]) -> Tuple[Dict[str, Any], List[str]]:
    """
    Validate and sanitize WhatsApp settings input
    
    Args:
        data: Raw input data
        
    Returns:
        Tuple of (sanitized_data, validation_errors)
    """
    errors = []
    sanitized = {}
    
    # Define validation rules
    validation_rules = {
        'green_api_instance_id': {
            'required': False,
            'type': str,
            'max_length': 50,
            'pattern': r'^[0-9]+$'  # Should be numeric
        },
        'green_api_token': {
            'required': False,
            'type': str,
            'max_length': 200,
            'min_length': 10
        },
        'reminder_template_7_days': {
            'required': False,
            'type': str,
            'max_length': 1000,
            'min_length': 1
        },
        'reminder_template_due_today': {
            'required': False,
            'type': str,
            'max_length': 1000,
            'min_length': 1
        },
        'reminder_template_manual': {
            'required': False,
            'type': str,
            'max_length': 1000,
            'min_length': 1
        },
        'is_enabled': {
            'required': False,
            'type': bool
        }
    }
    
    for field, rules in validation_rules.items():
        value = data.get(field)
        
        # Skip if not provided and not required
        if value is None and not rules.get('required', False):
            continue
        
        # Check if required field is present
        if rules.get('required', False) and (value is None or value == ''):
            errors.append(f'{field} is required')
            continue
        
        # Type validation
        if value is not None and not isinstance(value, rules['type']):
            errors.append(f'{field} must be of type {rules["type"].__name__}')
            continue
        
        # String-specific validations
        if isinstance(value, str):
            # Length validation
            if rules.get('min_length') and len(value) < rules['min_length']:
                errors.append(f'{field} must be at least {rules["min_length"]} characters')
                continue
            
            if rules.get('max_length') and len(value) > rules['max_length']:
                errors.append(f'{field} must be no more than {rules["max_length"]} characters')
                continue
            
            # Pattern validation
            if rules.get('pattern'):
                import re
                if not re.match(rules['pattern'], value):
                    errors.append(f'{field} format is invalid')
                    continue
            
            # Sanitize string
            sanitized[field] = value.strip()
        else:
            # Non-string values
            sanitized[field] = value
    
    # Validate templates if provided
    template_fields = ['reminder_template_7_days', 'reminder_template_due_today', 'reminder_template_manual']
    for template_field in template_fields:
        if template_field in sanitized:
            template_valid, template_errors = MessageTemplateProcessor.validate_template(sanitized[template_field])
            if not template_valid:
                errors.extend([f'{template_field}: {error}' for error in template_errors])
    
    # Business logic validation
    if sanitized.get('is_enabled'):
        if not sanitized.get('green_api_instance_id') or not sanitized.get('green_api_token'):
            errors.append('Green API credentials are required when enabling WhatsApp reminders')
    
    return sanitized, errors

def test_whatsapp_connection(instance_id: str, token: str) -> Dict[str, Any]:
    """
    Test WhatsApp connection with provided credentials
    
    Args:
        instance_id: Green API instance ID
        token: Green API token
        
    Returns:
        Connection test result
    """
    try:
        whatsapp_service = WhatsAppService(instance_id, token)
        success, error_message = whatsapp_service.test_connection()
        
        result = {
            'success': success,
            'message': 'Connection successful' if success else error_message,
            'tested_at': datetime.utcnow().isoformat()
        }
        
        if success:
            logger.info("WhatsApp connection test successful")
        else:
            logger.warning(f"WhatsApp connection test failed: {error_message}")
        
        return result
        
    except Exception as e:
        logger.error(f"WhatsApp connection test error: {e}")
        return {
            'success': False,
            'message': f'Connection test error: {str(e)}',
            'tested_at': datetime.utcnow().isoformat()
        }

# Import datetime for connection test
from datetime import datetime