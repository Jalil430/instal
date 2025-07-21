import os
import sys
import json
import logging
from datetime import datetime
from typing import Dict, Any

# Add shared modules to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from whatsapp_service import WhatsAppService
from jwt_auth import JWTAuth

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def handler(event, context):
    """
    Yandex Cloud Function handler to test WhatsApp connection
    
    POST /whatsapp/test-connection
    
    Request body:
    {
        "green_api_instance_id": "string",
        "green_api_token": "string"
    }
    
    Returns connection test results without saving credentials
    """
    try:
        logger.info(f"WhatsApp connection test request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
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
        
        # Validate required fields
        instance_id = body.get('green_api_instance_id', '').strip()
        token = body.get('green_api_token', '').strip()
        
        if not instance_id or not token:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Both green_api_instance_id and green_api_token are required'
                })
            }
        
        # Validate instance ID format
        if not instance_id.isdigit():
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'green_api_instance_id must be numeric'
                })
            }
        
        # Validate token length
        if len(token) < 10:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'green_api_token appears to be too short'
                })
            }
        
        logger.info(f"Testing WhatsApp connection for user {user_id} with instance {instance_id[:4]}****")
        
        # Perform connection test
        test_result = perform_connection_test(instance_id, token, user_id)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(test_result)
        }
        
    except Exception as e:
        logger.error(f"WhatsApp connection test failed: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Connection test failed',
                'message': str(e)
            })
        }

def perform_connection_test(instance_id: str, token: str, user_id: str) -> Dict[str, Any]:
    """
    Perform comprehensive WhatsApp connection test
    
    Args:
        instance_id: Green API instance ID
        token: Green API token
        user_id: User ID for logging
        
    Returns:
        Detailed connection test results
    """
    test_start_time = datetime.utcnow()
    
    try:
        # Initialize WhatsApp service
        whatsapp_service = WhatsAppService(instance_id, token)
        
        # Perform basic connection test
        success, error_message = whatsapp_service.test_connection()
        
        test_end_time = datetime.utcnow()
        response_time_ms = int((test_end_time - test_start_time).total_seconds() * 1000)
        
        result = {
            'success': success,
            'message': error_message if not success else 'Connection successful',
            'instance_id': instance_id[:4] + '****' + instance_id[-2:] if len(instance_id) > 6 else '****',
            'tested_at': test_start_time.isoformat(),
            'response_time_ms': response_time_ms,
            'test_details': {
                'endpoint_reachable': success,
                'credentials_valid': success,
                'api_responsive': response_time_ms < 10000  # Less than 10 seconds
            }
        }
        
        if success:
            logger.info(f"WhatsApp connection test successful for user {user_id} (response time: {response_time_ms}ms)")
            result['recommendations'] = get_success_recommendations()
        else:
            logger.warning(f"WhatsApp connection test failed for user {user_id}: {error_message}")
            result['recommendations'] = get_failure_recommendations(error_message)
            result['troubleshooting'] = get_troubleshooting_tips(error_message)
        
        return result
        
    except Exception as e:
        test_end_time = datetime.utcnow()
        response_time_ms = int((test_end_time - test_start_time).total_seconds() * 1000)
        
        logger.error(f"WhatsApp connection test error for user {user_id}: {e}")
        
        return {
            'success': False,
            'message': f'Connection test error: {str(e)}',
            'instance_id': instance_id[:4] + '****' + instance_id[-2:] if len(instance_id) > 6 else '****',
            'tested_at': test_start_time.isoformat(),
            'response_time_ms': response_time_ms,
            'test_details': {
                'endpoint_reachable': False,
                'credentials_valid': False,
                'api_responsive': False
            },
            'recommendations': get_error_recommendations(),
            'troubleshooting': get_troubleshooting_tips(str(e))
        }

def get_success_recommendations() -> list:
    """Get recommendations for successful connection"""
    return [
        "Your Green API connection is working properly",
        "You can now enable WhatsApp reminders in your settings",
        "Test sending a manual reminder to verify message delivery",
        "Consider customizing your message templates"
    ]

def get_failure_recommendations(error_message: str) -> list:
    """Get recommendations for failed connection"""
    recommendations = [
        "Verify your Green API instance ID and token are correct",
        "Check that your Green API account is active and not suspended",
        "Ensure your Green API instance is authorized and connected to WhatsApp"
    ]
    
    if "401" in error_message or "unauthorized" in error_message.lower():
        recommendations.extend([
            "Double-check your API token - it may be incorrect or expired",
            "Verify the instance ID matches your Green API account"
        ])
    elif "timeout" in error_message.lower() or "connection" in error_message.lower():
        recommendations.extend([
            "Check your internet connection",
            "Try again in a few minutes - the service may be temporarily unavailable"
        ])
    
    return recommendations

def get_error_recommendations() -> list:
    """Get recommendations for connection errors"""
    return [
        "Check your internet connection and try again",
        "Verify that Green API service is accessible",
        "Contact support if the problem persists",
        "Ensure your credentials are entered correctly"
    ]

def get_troubleshooting_tips(error_message: str) -> Dict[str, Any]:
    """Get troubleshooting tips based on error message"""
    tips = {
        'common_issues': [
            "Incorrect instance ID or token",
            "Green API account not activated",
            "WhatsApp not connected to the instance",
            "Network connectivity issues"
        ],
        'next_steps': [
            "Log into your Green API dashboard",
            "Verify your instance status",
            "Check WhatsApp connection status",
            "Regenerate API token if needed"
        ]
    }
    
    if "401" in error_message or "unauthorized" in error_message.lower():
        tips['specific_issue'] = "Authentication failed - check your credentials"
        tips['solution'] = "Verify instance ID and token in your Green API dashboard"
    elif "timeout" in error_message.lower():
        tips['specific_issue'] = "Connection timeout - service may be slow or unavailable"
        tips['solution'] = "Wait a few minutes and try again"
    elif "connection" in error_message.lower():
        tips['specific_issue'] = "Network connection problem"
        tips['solution'] = "Check your internet connection and firewall settings"
    else:
        tips['specific_issue'] = "Unknown error occurred"
        tips['solution'] = "Contact support with the error details"
    
    return tips