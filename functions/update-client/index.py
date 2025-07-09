import os
import json
import ydb
import re
import hmac
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
    def validate_client_id(client_id: str) -> tuple[str, Optional[str]]:
        """Validate and sanitize client ID"""
        if not client_id:
            return None, "Client ID is required"
        
        # UUID format validation
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, client_id.lower()):
            return None, "Invalid client ID format"
        
        # Sanitize - convert to lowercase
        return client_id.lower(), None

    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data for updates"""
        errors = []
        sanitized = {}
        
        # Define validation rules, all fields are optional for update
        validation_rules = {
            'full_name': {
                'type': str, 'min_length': 1, 'max_length': 100
                # No pattern restriction - allow any Unicode characters
            },
            'contact_number': {
                'type': str, 'min_length': 1, 'max_length': 50
                # No pattern restriction - allow any format
            },
            'passport_number': {
                'type': str, 'min_length': 1, 'max_length': 50
                # No pattern restriction - allow any format/script
            },
            'address': {
                'type': str, 'min_length': 0, 'max_length': 500
                # No pattern restriction - allow any Unicode characters
            }
        }
        
        for field, rules in validation_rules.items():
            if field not in data:
                continue

            value = data.get(field)
            
            if value is None or value == '':
                sanitized[field] = None
                continue
            
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a string')
                continue
            
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
    Yandex Cloud Function handler to update a client by ID.
    """
    try:
        logger.info(f"Received update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        path_params = event.get('pathParameters', {})
        client_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_client_id(client_id)
        if validation_error:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': validation_error})}
        
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
        
        if not body:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Request body cannot be empty'})}

        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        if validation_errors:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})}

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)
            
            def update_client_in_db(session):
                # First, check if the client exists and belongs to the authenticated user
                check_query = """
                DECLARE $client_id AS Utf8;
                DECLARE $user_id AS Utf8;
                SELECT id FROM clients WHERE id = $client_id AND user_id = $user_id;
                """
                prepared_check = session.prepare(check_query)
                result_sets = session.transaction().execute(
                    prepared_check, 
                    {'$client_id': sanitized_id, '$user_id': user_id}, 
                    commit_tx=True
                )
                if not result_sets[0].rows:
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Client not found'})}

                # Build UPDATE query for the provided field(s)
                if not sanitized_data:
                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'No fields to update'})}

                # Handle each field separately with individual queries for simplicity
                current_time = datetime.utcnow()
                
                if 'full_name' in sanitized_data:
                    update_query = """
                    DECLARE $client_id AS Utf8;
                    DECLARE $full_name AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE clients 
                    SET full_name = $full_name, updated_at = $updated_at 
                    WHERE id = $client_id;
                    """
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$client_id': sanitized_id,
                            '$full_name': sanitized_data['full_name'],
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                if 'contact_number' in sanitized_data:
                    update_query = """
                    DECLARE $client_id AS Utf8;
                    DECLARE $contact_number AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE clients 
                    SET contact_number = $contact_number, updated_at = $updated_at 
                    WHERE id = $client_id;
                    """
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$client_id': sanitized_id,
                            '$contact_number': sanitized_data['contact_number'],
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                if 'passport_number' in sanitized_data:
                    update_query = """
                    DECLARE $client_id AS Utf8;
                    DECLARE $passport_number AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE clients 
                    SET passport_number = $passport_number, updated_at = $updated_at 
                    WHERE id = $client_id;
                    """
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$client_id': sanitized_id,
                            '$passport_number': sanitized_data['passport_number'],
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                if 'address' in sanitized_data:
                    update_query = """
                    DECLARE $client_id AS Utf8;
                    DECLARE $address AS Utf8?;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE clients 
                    SET address = $address, updated_at = $updated_at 
                    WHERE id = $client_id;
                    """
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$client_id': sanitized_id,
                            '$address': sanitized_data['address'],
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                logger.info(f"Client updated successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Client updated successfully'})}

            result = pool.retry_operation_sync(update_client_in_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 