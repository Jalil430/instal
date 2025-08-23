import os
import json
import jwt
import hmac
import logging
from typing import Dict, Any, Optional, Tuple

logger = logging.getLogger(__name__)

class JWTAuth:
    """Handles JWT token authentication and validation"""

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

    @staticmethod
    def extract_token_from_event(event: dict) -> Optional[str]:
        """Extract JWT token from Authorization header"""
        headers = event.get('headers', {})

        # Handle case-insensitive headers
        auth_header = None
        for key, value in headers.items():
            if key.lower() == 'authorization':
                auth_header = value
                break

        if not auth_header:
            return None

        # Extract token from Bearer header
        if not auth_header.startswith('Bearer '):
            return None

        return auth_header[7:]  # Remove 'Bearer ' prefix

    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        """
        Authenticate request and return user_id and error message
        Returns: (user_id, error_message)
        """
        try:
            # Extract JWT token
            token = JWTAuth.extract_token_from_event(event)

            if not token:
                return None, "Authorization header missing or invalid format"

            # Verify token
            payload = JWTAuth.verify_jwt_token(token, 'access')
            user_id = payload.get('user_id')

            if not user_id:
                return None, "Invalid token: user_id not found"

            logger.info(f"Request authenticated for user: {payload.get('email', 'unknown')}")
            return user_id, None

        except ValueError as e:
            return None, f"Authentication failed: {str(e)}"
        except Exception as e:
            logger.error(f"Unexpected authentication error: {e}")
            return None, "Authentication error"

def jwt_required(func):
    """Decorator to require JWT authentication"""
    def wrapper(event, context):
        # Try JWT authentication first
        user_id, error = JWTAuth.authenticate_request(event)

        if not user_id:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': error or 'Authentication required'})
            }

        # Add user_id to event for handler access
        if 'requestContext' not in event:
            event['requestContext'] = {}
        if 'authorizer' not in event['requestContext']:
            event['requestContext']['authorizer'] = {}
        event['requestContext']['authorizer']['user_id'] = user_id

        return func(event, context)

    return wrapper
