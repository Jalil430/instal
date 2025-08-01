import os
import json
import ydb
import re
import hashlib
import hmac
import jwt
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecurityValidator:
    """Handles input validation and sanitization"""
    
    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data for token refresh"""
        errors = []
        sanitized = {}
        
        # Define validation rules
        validation_rules = {
            'refresh_token': {
                'required': True,
                'type': str,
                'min_length': 10,
                'max_length': 2000,
            }
        }
        
        for field, rules in validation_rules.items():
            value = data.get(field)
            
            # Check if required field is present
            if rules['required'] and (value is None or value == ''):
                errors.append(f'{field} is required')
                continue
            
            # Type validation
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a string')
                continue
            
            # Length validation
            if len(value) < rules['min_length']:
                errors.append(f'{field} must be at least {rules["min_length"]} characters')
                continue
            
            if len(value) > rules['max_length']:
                errors.append(f'{field} must be no more than {rules["max_length"]} characters')
                continue
            
            # Sanitize (trim whitespace only)
            sanitized_value = value.strip()
            sanitized[field] = sanitized_value
        
        return sanitized, errors

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
    def verify_jwt_token(token: str, token_type: str = 'refresh') -> dict:
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
    def generate_jwt_token(user_id: str, email: str) -> dict:
        """Generate JWT access and refresh tokens"""
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        
        # Access token (expires in 7 days)
        access_payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.utcnow() + timedelta(days=7),
            'iat': datetime.utcnow(),
            'type': 'access'
        }
        
        # Refresh token (expires in 30 days)
        refresh_payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.utcnow() + timedelta(days=30),
            'iat': datetime.utcnow(),
            'type': 'refresh'
        }
        
        access_token = jwt.encode(access_payload, secret_key, algorithm='HS256')
        refresh_token = jwt.encode(refresh_payload, secret_key, algorithm='HS256')
        
        return {
            'access_token': access_token,
            'refresh_token': refresh_token,
            'expires_in': 604800  # 7 days in seconds
        }

def handler(event, context):
    """
    Yandex Cloud Function handler to refresh JWT tokens.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Token refresh request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. API Key Authentication
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized token refresh attempt")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})
            }
        
        # 2. Parse and validate request body
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
        
        # 3. Input validation and sanitization
        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        
        if validation_errors:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})
            }
        
        # 4. Verify refresh token
        try:
            payload = AuthUtils.verify_jwt_token(sanitized_data['refresh_token'], 'refresh')
            user_id = payload['user_id']
            email = payload['email']
            
        except ValueError as e:
            logger.warning(f"Token refresh failed: {e}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid or expired refresh token'})
            }
        
        # 5. Verify user still exists in database
        try:
            # Use metadata authentication
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            
            # Create session pool
            pool = ydb.SessionPool(driver)
            
            def verify_user_exists(session):
                # Check if user still exists
                query = """
                DECLARE $user_id AS Utf8;
                SELECT id, email, full_name FROM users WHERE id = $user_id;
                """
                
                prepared_query = session.prepare(query)
                result = session.transaction().execute(
                    prepared_query, {'$user_id': user_id},
                    commit_tx=True
                )
                
                if len(result[0].rows) == 0:
                    raise ValueError("User no longer exists")
                
                user_row = result[0].rows[0]
                return {
                    'user_id': user_row['id'],
                    'email': user_row['email'],
                    'full_name': user_row['full_name']
                }
            
            # Execute database operation
            user_data = pool.retry_operation_sync(verify_user_exists)
            
            # Generate new JWT tokens
            tokens = AuthUtils.generate_jwt_token(user_data['user_id'], user_data['email'])
            
            logger.info(f"Token refreshed successfully for user: {user_data['email']}")
            
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'message': 'Token refreshed successfully',
                    'user_id': user_data['user_id'],
                    'email': user_data['email'],
                    'full_name': user_data['full_name'],
                    **tokens
                })
            }
            
        except ValueError as e:
            logger.warning(f"User verification failed during token refresh: {e}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'User verification failed'})
            }
        except Exception as e:
            logger.error(f"Database error during token refresh: {e}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Token refresh failed. Please try again.'})
            }
        
        finally:
            try:
                driver.stop()
            except Exception:
                pass
    
    except Exception as e:
        logger.error(f"Unexpected error in token refresh: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        } 