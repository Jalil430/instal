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

class ApiKeyAuth:
    """Handles API key authentication (kept for backward compatibility)"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        """Validate API key from request headers"""
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured in environment")
            return False
        
        headers = event.get('headers', {})
        api_key = None
        for key, value in headers.items():
            if key.lower() == 'x-api-key':
                api_key = value
                break
        
        if not api_key:
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

class HybridAuth:
    """Handles both JWT and API key authentication"""
    
    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        """
        Authenticate request using JWT first, fallback to API key
        Returns: (user_id, error_message)
        """
        # Try JWT authentication first
        user_id, jwt_error = JWTAuth.authenticate_request(event)
        if user_id:
            return user_id, None
        
        # Fallback to API key authentication (for backward compatibility)
        if ApiKeyAuth.validate_api_key(event):
            # For API key auth, we need user_id from request body or query params
            # This is for backward compatibility only
            query_params = event.get('queryStringParameters') or {}
            user_id_from_query = query_params.get('user_id')
            
            if user_id_from_query:
                logger.info("Request authenticated with API key (legacy mode)")
                return user_id_from_query, None
            
            # Try to get user_id from request body
            try:
                raw_body = event.get('body', '{}')
                try:
                    import base64
                    decoded_body = base64.b64decode(raw_body).decode('utf-8')
                    body = json.loads(decoded_body)
                except Exception:
                    body = json.loads(raw_body)
                
                user_id_from_body = body.get('user_id')
                if user_id_from_body:
                    logger.info("Request authenticated with API key (legacy mode)")
                    return user_id_from_body, None
                    
            except (json.JSONDecodeError, Exception):
                pass
            
            return None, "API key authentication requires user_id parameter"
        
        # Both authentication methods failed
        return None, f"Authentication failed: {jwt_error}" 