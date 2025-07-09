import os
import json
import uuid
import ydb
import re
import hashlib
import hmac
import jwt
import bcrypt
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
        """Validate and sanitize input data for user registration"""
        errors = []
        sanitized = {}
        
        # Define validation rules
        validation_rules = {
            'email': {
                'required': True,
                'type': str,
                'min_length': 3,
                'max_length': 100,
                'pattern': r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            },
            'password': {
                'required': True,
                'type': str,
                'min_length': 8,
                'max_length': 128,
            },
            'full_name': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 100,
            },
            'phone': {
                'required': False,
                'type': str,
                'min_length': 0,
                'max_length': 20,
            }
        }
        
        for field, rules in validation_rules.items():
            value = data.get(field)
            
            # Check if required field is present
            if rules['required'] and (value is None or value == ''):
                errors.append(f'{field} is required')
                continue
            
            # Skip validation for optional empty fields
            if not rules['required'] and (value is None or value == ''):
                sanitized[field] = None
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
            
            # Pattern validation (only if pattern is defined)
            if rules.get('pattern') and not re.match(rules['pattern'], value):
                if field == 'email':
                    errors.append(f'{field} must be a valid email address')
                else:
                    errors.append(f'{field} contains invalid characters')
                continue
            
            # Sanitize (trim whitespace only, preserve Unicode characters)
            sanitized_value = value.strip()
            
            sanitized[field] = sanitized_value
        
        # Additional password validation
        if 'password' in sanitized:
            password = sanitized['password']
            if not re.search(r'[A-Za-z]', password):
                errors.append('Password must contain at least one letter')
            if not re.search(r'\d', password):
                errors.append('Password must contain at least one number')
        
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
    """Authentication utilities for JWT and password handling"""
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash password using bcrypt"""
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    
    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        """Verify password against bcrypt hash"""
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
    
    @staticmethod
    def generate_jwt_token(user_id: str, email: str) -> dict:
        """Generate JWT access and refresh tokens"""
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        
        # Access token (expires in 1 hour)
        access_payload = {
            'user_id': user_id,
            'email': email,
            'exp': datetime.utcnow() + timedelta(hours=1),
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
            'expires_in': 3600  # 1 hour in seconds
        }

def handler(event, context):
    """
    Yandex Cloud Function handler to register a new user.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Registration request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. API Key Authentication
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized registration attempt")
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
        
        # 4. Database operations
        try:
            # Use metadata authentication with extended timeout
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            
            # Create session pool
            pool = ydb.SessionPool(driver)
            
            def register_user(session):
                # Check if user with email already exists
                query = """
                DECLARE $email AS Utf8;
                SELECT id FROM users WHERE email = $email;
                """
                
                prepared_query = session.prepare(query)
                result = session.transaction().execute(
                    prepared_query, {'$email': sanitized_data['email']},
                    commit_tx=True
                )
                
                if len(result[0].rows) > 0:
                    raise ValueError("User with this email already exists")
                
                # Generate user ID and hash password
                user_id = str(uuid.uuid4())
                hashed_password = AuthUtils.hash_password(sanitized_data['password'])
                current_time = datetime.utcnow().isoformat() + 'Z'
                
                # Insert new user
                insert_query = """
                DECLARE $id AS Utf8;
                DECLARE $email AS Utf8;
                DECLARE $password_hash AS Utf8;
                DECLARE $full_name AS Utf8;
                DECLARE $phone AS Utf8?;
                DECLARE $created_at AS Utf8;
                DECLARE $updated_at AS Utf8;
                
                UPSERT INTO users (id, email, password_hash, full_name, phone, created_at, updated_at)
                VALUES ($id, $email, $password_hash, $full_name, $phone, $created_at, $updated_at);
                """
                
                prepared_insert = session.prepare(insert_query)
                session.transaction().execute(
                    prepared_insert,
                    {
                        '$id': user_id,
                        '$email': sanitized_data['email'],
                        '$password_hash': hashed_password,
                        '$full_name': sanitized_data['full_name'],
                        '$phone': sanitized_data.get('phone'),
                        '$created_at': current_time,
                        '$updated_at': current_time,
                    },
                    commit_tx=True
                )
                
                return user_id
            
            # Execute database operation
            user_id = pool.retry_operation_sync(register_user)
            
            # Generate JWT tokens
            tokens = AuthUtils.generate_jwt_token(user_id, sanitized_data['email'])
            
            logger.info(f"User registered successfully: {sanitized_data['email']}")
            
            return {
                'statusCode': 201,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'message': 'User registered successfully',
                    'user_id': user_id,
                    'email': sanitized_data['email'],
                    'full_name': sanitized_data['full_name'],
                    **tokens
                })
            }
            
        except ValueError as e:
            logger.warning(f"Registration validation error: {e}")
            return {
                'statusCode': 409,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': str(e)})
            }
        except Exception as e:
            logger.error(f"Database error during registration: {type(e).__name__}: {e}")
            logger.error(f"YDB_ENDPOINT: {os.environ.get('YDB_ENDPOINT')}")
            logger.error(f"YDB_DATABASE: {os.environ.get('YDB_DATABASE')}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Registration failed: {type(e).__name__}: {str(e)}'})
            }
        
        finally:
            try:
                driver.stop()
            except Exception:
                pass
    
    except Exception as e:
        logger.error(f"Unexpected error in registration: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        } 