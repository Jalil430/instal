import os
import json
import ydb
import re
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
        """Validate and sanitize input data for user profile update"""
        errors = []
        sanitized = {}
        
        # Define validation rules - only full_name and phone can be updated
        validation_rules = {
            'full_name': {
                'type': str,
                'min_length': 1,
                'max_length': 100
            },
            'phone': {
                'type': str,
                'min_length': 0,  # Allow empty phone (optional field)
                'max_length': 20,
                'pattern': r'^[\+]?[0-9\s\-\(\)]*$'  # Allow international format with spaces, dashes, parentheses
            }
        }
        
        for field, rules in validation_rules.items():
            if field not in data:
                continue
                
            value = data.get(field)
            
            # Allow null/empty for optional fields
            if value is None or value == '':
                if field == 'phone':
                    sanitized[field] = None  # Store as null for optional phone
                    continue
                elif field == 'full_name':
                    errors.append(f'{field} cannot be empty')
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
            
            # Sanitize (trim whitespace)
            sanitized_value = value.strip()
            sanitized[field] = sanitized_value
        
        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to update user profile information.
    Only allows updating full_name and phone (not email).
    """
    try:
        logger.info(f"User update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
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
        
        # Check if body has any fields to update
        if not body:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Request body cannot be empty'})
            }
        
        # 3. Input validation and sanitization
        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        
        if validation_errors:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})
            }
        
        # Check if there are fields to update
        if not sanitized_data:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'No valid fields to update'})
            }
        
        # 4. Database operations
        try:
            # Use metadata authentication
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials(),
            )
            
            with ydb.Driver(driver_config) as driver:
                driver.wait(fail_fast=True, timeout=5)
                
                with ydb.SessionPool(driver) as pool:
                    def update_user_profile(session):
                        # First, get the current user to verify they exist
                        query = """
                        DECLARE $user_id AS Utf8;
                        SELECT id, email, full_name, phone, created_at
                        FROM users 
                        WHERE id = $user_id;
                        """
                        
                        prepared_query = session.prepare(query)
                        result_sets = session.transaction().execute(
                            prepared_query, 
                            {'$user_id': user_id},
                            commit_tx=True
                        )
                        
                        users = []
                        for result_set in result_sets:
                            for row in result_set.rows:
                                users.append(row)
                        
                        if not users:
                            logger.warning(f"User not found: {user_id}")
                            return None
                        
                        current_user = users[0]
                        
                        # Build the update query dynamically
                        update_parts = []
                        params = {'$user_id': user_id}
                        declarations = ['DECLARE $user_id AS Utf8;']
                        
                        for field, value in sanitized_data.items():
                            param_name = f'${field}'
                            update_parts.append(f'{field} = {param_name}')
                            params[param_name] = value
                            declarations.append(f'DECLARE {param_name} AS Utf8;')
                        
                        update_set_clause = ', '.join(update_parts)
                        declarations_clause = '\n'.join(declarations)
                        
                        query = f"""
                        {declarations_clause}
                        UPDATE users
                        SET {update_set_clause}
                        WHERE id = $user_id;
                        """
                        
                        prepared_query = session.prepare(query)
                        session.transaction().execute(
                            prepared_query,
                            params,
                            commit_tx=True
                        )
                        
                        # Finally, get the updated user data to return
                        query = """
                        DECLARE $user_id AS Utf8;
                        SELECT id, email, full_name, phone, created_at, updated_at
                        FROM users 
                        WHERE id = $user_id;
                        """
                        
                        prepared_query = session.prepare(query)
                        result_sets = session.transaction().execute(
                            prepared_query, 
                            {'$user_id': user_id},
                            commit_tx=True
                        )
                        
                        updated_users = []
                        for result_set in result_sets:
                            for row in result_set.rows:
                                updated_users.append(row)
                        
                        if not updated_users:
                            logger.error(f"Failed to retrieve updated user: {user_id}")
                            return None
                        
                        updated_user = updated_users[0]

                        # Ensure timestamps are datetime objects before formatting
                        created_at_dt = updated_user.created_at
                        if isinstance(created_at_dt, str):
                            created_at_dt = datetime.fromisoformat(created_at_dt.replace('Z', '+00:00'))

                        updated_at_dt = updated_user.updated_at
                        if isinstance(updated_at_dt, str):
                            updated_at_dt = datetime.fromisoformat(updated_at_dt.replace('Z', '+00:00'))
                        
                        return {
                            'id': updated_user.id,
                            'email': updated_user.email,
                            'full_name': updated_user.full_name,
                            'phone': updated_user.phone,
                            'created_at': created_at_dt.isoformat(),
                            'updated_at': updated_at_dt.isoformat()
                        }
                    
                    updated_user_data = pool.retry_operation_sync(update_user_profile)
                    
                    if not updated_user_data:
                        return {
                            'statusCode': 404,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'User not found'})
                        }
                    
                    logger.info(f"User profile updated successfully: {updated_user_data['email']}")
                    
                    return {
                        'statusCode': 200,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps(updated_user_data)
                    }
        
        except Exception as e:
            logger.error(f"Database error during user update: {e}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database error during user update'})
            }
    
    except Exception as e:
        logger.error(f"Unexpected error in user update: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        } 