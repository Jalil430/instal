import os
import json
import uuid
import ydb
import re
import hashlib
import hmac
import jwt
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
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

class SecurityValidator:
    """Handles input validation and sanitization"""
    
    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data"""
        errors = []
        sanitized = {}
        
        # Define validation rules
        validation_rules = {
            'full_name': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 100,
                # No pattern restriction - allow any Unicode characters
            },
            'contact_number': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 50,
                # No pattern restriction - allow any format
            },
            'passport_number': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 50,
                # No pattern restriction - allow any format/script
            },
            'address': {
                'required': False,
                'type': str,
                'min_length': 0,
                'max_length': 500,
                # No pattern restriction - allow any Unicode characters
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
                errors.append(f'{field} contains invalid characters')
                continue
            
            # Sanitize (trim whitespace only, preserve Unicode characters)
            sanitized_value = value.strip()
            
            sanitized[field] = sanitized_value
        
        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to create a new client with enhanced security.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Received request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
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
        
        # 4. Database operations with enhanced error handling
        try:
            # Use metadata authentication (automatic, secure, no manual tokens)
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            
            # Create session pool
            pool = ydb.SessionPool(driver)
            
            def check_and_create_client(session):
                # Check if client with passport number already exists
                query = """
                DECLARE $passport_number AS Utf8;
                SELECT id FROM clients WHERE passport_number = $passport_number;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    {'$passport_number': sanitized_data['passport_number']},
                    commit_tx=True
                )
                
                if result_sets[0].rows:
                    logger.info(f"Duplicate passport number attempt: {sanitized_data['passport_number'][:4]}****")
                    return {
                        'statusCode': 409,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Client with this passport number already exists'})
                    }

                # Create new client
                new_client_id = str(uuid.uuid4())
                current_time = datetime.utcnow()
                
                insert_query = """
                DECLARE $id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $full_name AS Utf8;
                DECLARE $contact_number AS Utf8;
                DECLARE $passport_number AS Utf8;
                DECLARE $address AS Utf8?;
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;
                
                INSERT INTO clients (id, user_id, full_name, contact_number, passport_number, address, created_at, updated_at) 
                VALUES ($id, $user_id, $full_name, $contact_number, $passport_number, $address, $created_at, $updated_at);
                """
                
                prepared_insert = session.prepare(insert_query)
                session.transaction().execute(
                    prepared_insert,
                    {
                        '$id': new_client_id,
                        '$user_id': user_id,
                        '$full_name': sanitized_data['full_name'],
                        '$contact_number': sanitized_data['contact_number'],
                        '$passport_number': sanitized_data['passport_number'],
                        '$address': sanitized_data.get('address'),
                        '$created_at': current_time,
                        '$updated_at': current_time
                    },
                    commit_tx=True
                )
                
                logger.info(f"Client created successfully: {new_client_id}")
                return {
                    'statusCode': 201,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'id': new_client_id})
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(check_and_create_client)
            
            # Clean up
            driver.stop()
            
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database operation failed'})
            }
        
        except Exception as e:
            logger.error(f"Database connection error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database connection failed'})
            }
            
    except Exception as e:
        # Generic error handler - don't expose internal details
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }