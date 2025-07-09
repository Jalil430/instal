import os
import json
import uuid
import ydb
import re
import hashlib
import jwt
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
from decimal import Decimal

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
        
        validation_rules = {
            'full_name': {'required': True, 'type': str, 'min_length': 1, 'max_length': 100},  # No pattern restriction
            'investment_amount': {'required': True, 'type': (int, float)},
            'investor_percentage': {'required': True, 'type': (int, float)},
            'user_percentage': {'required': True, 'type': (int, float)},
        }
        
        for field, rules in validation_rules.items():
            value = data.get(field)
            
            if rules['required'] and value is None:
                errors.append(f'{field} is required')
                continue
            
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a number')
                continue

            if 'min_length' in rules and len(value) < rules['min_length']:
                errors.append(f'{field} must be at least {rules["min_length"]} characters')
            
            if 'max_length' in rules and len(value) > rules['max_length']:
                errors.append(f'{field} must be no more than {rules["max_length"]} characters')

            # Pattern validation (only if pattern is defined)
            if rules.get('pattern') and isinstance(value, str) and not re.match(rules['pattern'], value):
                errors.append(f'{field} contains invalid characters')
                continue
            
            # Sanitize string fields (trim whitespace only, preserve Unicode characters)
            if isinstance(value, str):
                sanitized[field] = value.strip()
            else:
                sanitized[field] = value
        
        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to create a new investor.
    """
    try:
        logger.info(f"Received create investor request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
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
        except json.JSONDecodeError:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON in request body'})}
        
        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        
        if validation_errors:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})}
        
        # Use authenticated user_id instead of body user_id for security
        sanitized_data['user_id'] = user_id
        
        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)
            
            def create_investor(session):
                new_investor_id = str(uuid.uuid4())
                current_time = datetime.utcnow()
                
                # Convert numeric values to Decimal to match YDB schema
                investment_amount = Decimal(str(sanitized_data['investment_amount']))
                investor_percentage = Decimal(str(sanitized_data['investor_percentage']))
                user_percentage = Decimal(str(sanitized_data['user_percentage']))
                
                query = """
                DECLARE $id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $full_name AS Utf8;
                DECLARE $investment_amount AS Decimal(22,9);
                DECLARE $investor_percentage AS Decimal(22,9);
                DECLARE $user_percentage AS Decimal(22,9);
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;
                
                INSERT INTO investors (id, user_id, full_name, investment_amount, investor_percentage, user_percentage, created_at, updated_at) 
                VALUES ($id, $user_id, $full_name, $investment_amount, $investor_percentage, $user_percentage, $created_at, $updated_at);
                """
                
                prepared_query = session.prepare(query)
                session.transaction().execute(
                    prepared_query,
                    {
                        '$id': new_investor_id,
                        '$user_id': user_id,
                        '$full_name': sanitized_data['full_name'],
                        '$investment_amount': investment_amount,
                        '$investor_percentage': investor_percentage,
                        '$user_percentage': user_percentage,
                        '$created_at': current_time,
                        '$updated_at': current_time
                    },
                    commit_tx=True
                )
                
                logger.info(f"Investor created successfully: {new_investor_id}")
                return {
                    'statusCode': 201,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'id': new_investor_id})
                }
            
            return pool.retry_operation_sync(create_investor)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 