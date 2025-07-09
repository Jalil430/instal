import os
import json
import jwt
import hmac
import logging
from datetime import datetime
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ApiKeyAuth:
    """Handles API key authentication"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        """Validate API key from request headers"""
        # Get API key from environment
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured in environment")
            return False
        
        # Get API key from headers
        headers = event.get('headers', {})
        # Handle case-insensitive headers
        api_key = None
        for key, value in headers.items():
            if key.lower() == 'x-api-key':
                api_key = value
                break
        
        if not api_key:
            logger.warning("No API key provided in request")
            return False
        
        # Use constant-time comparison to prevent timing attacks
        return hmac.compare_digest(expected_api_key, api_key)

class AuthUtils:
    """Authentication utilities for JWT handling"""
    
    @staticmethod
    def verify_jwt_token(token: str, token_type: str = 'access') -> dict:
        """Verify and decode JWT token"""
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            
            # Check token type
            if payload.get('type') != token_type:
                raise ValueError(f"Invalid token type. Expected {token_type}")
            
            return payload
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid token")

def handler(event, context):
    """
    Yandex Cloud Function handler to verify JWT tokens.
    This function is used by other services to validate user authentication.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Token verification request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. API Key Authentication (consistent with other auth functions)
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized token verification attempt")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})
            }
        
        # 2. Parse request body to get the JWT token
        try:
            raw_body = event.get('body', '{}')
            
            # Check if the body is Base64 encoded (common with Yandex Cloud Functions)
            try:
                # Try to decode as Base64 first
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                # If Base64 decoding fails, try parsing as plain JSON
                body = json.loads(raw_body)
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid JSON in request body'})
            }
        
        # Get token from request body
        token = body.get('access_token')
        
        if not token:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'access_token missing in request body'})
            }
        
        # Verify token
        try:
            payload = AuthUtils.verify_jwt_token(token, 'access')
            
            user_id = payload['user_id']
            email = payload['email']
            
            logger.info(f"Token verified successfully for user: {email}")
            
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'valid': True,
                    'user_id': user_id,
                    'email': email,
                    'exp': payload['exp'],
                    'iat': payload['iat']
                })
            }
            
        except ValueError as e:
            logger.warning(f"Token verification failed: {e}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid or expired token', 'valid': False})
            }
    
    except Exception as e:
        logger.error(f"Unexpected error in token verification: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        } 