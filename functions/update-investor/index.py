import os
import json
import ydb
import re

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
    def validate_investor_id(investor_id: str) -> tuple[str, Optional[str]]:
        """Validate and sanitize investor ID"""
        if not investor_id:
            return None, "Investor ID is required"
        
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, investor_id.lower()):
            return None, "Invalid investor ID format"
        
        return investor_id.lower(), None

    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data for updates"""
        errors = []
        sanitized = {}
        
        validation_rules = {
            'user_id': {'type': str, 'min_length': 1, 'max_length': 50, 'pattern': r'^[a-zA-Z0-9_-]+$'},
            'full_name': {'type': str, 'min_length': 1, 'max_length': 100},  # No pattern restriction
            'investment_amount': {'type': (int, float)},
            'investor_percentage': {'type': (int, float)},
            'user_percentage': {'type': (int, float)},
        }
        
        for field, rules in validation_rules.items():
            if field not in data:
                continue

            value = data.get(field)
            
            if value is None:
                sanitized[field] = None
                continue
            
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a number' if 'amount' in field or 'percentage' in field else f'{field} must be a string')
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
    Yandex Cloud Function handler to update an investor by ID.
    """
    try:
        logger.info(f"Received update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        path_params = event.get('pathParameters', {})
        investor_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_investor_id(investor_id)
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
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON'})}
        
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
            
            def update_investor_in_db(session):
                # First, check if the investor exists (using same pattern as get-investor)
                check_query = """
                DECLARE $investor_id AS Utf8;
                SELECT id FROM investors WHERE id = $investor_id;
                """
                prepared_check = session.prepare(check_query)
                result_sets = session.transaction().execute(
                    prepared_check, 
                    {'$investor_id': sanitized_id}, 
                    commit_tx=True
                )
                if not result_sets[0].rows:
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Investor not found'})}

                # Build a simple UPDATE query for the provided field(s)
                if not sanitized_data:
                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'No fields to update'})}

                # Handle common fields with static queries
                current_time = datetime.utcnow()
                
                # Handle full_name update
                if 'full_name' in sanitized_data:
                    # Use a single transaction to update both investor and related installments
                    tx = session.transaction(ydb.SerializableReadWrite())
                    
                    # Update investor name
                    update_investor_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $full_name AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET full_name = $full_name, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    tx.execute(
                        session.prepare(update_investor_query),
                        {
                            '$investor_id': sanitized_id,
                            '$full_name': sanitized_data['full_name'],
                            '$updated_at': current_time
                        }
                    )
                    
                    # Update investor_name in all related installments
                    update_installments_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $investor_name AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE installments 
                    SET investor_name = $investor_name, updated_at = $updated_at 
                    WHERE investor_id = $investor_id;
                    """
                    tx.execute(
                        session.prepare(update_installments_query),
                        {
                            '$investor_id': sanitized_id,
                            '$investor_name': sanitized_data['full_name'],
                            '$updated_at': current_time
                        }
                    )
                    
                    tx.commit()
                
                # Handle investment_amount update
                if 'investment_amount' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $investment_amount AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET investment_amount = $investment_amount, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$investment_amount': Decimal(str(sanitized_data['investment_amount'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                # Handle investor_percentage update
                if 'investor_percentage' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $investor_percentage AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET investor_percentage = $investor_percentage, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$investor_percentage': Decimal(str(sanitized_data['investor_percentage'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                # Handle user_percentage update
                if 'user_percentage' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $user_percentage AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET user_percentage = $user_percentage, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$user_percentage': Decimal(str(sanitized_data['user_percentage'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )

                logger.info(f"Investor updated successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Investor updated successfully'})}

            return pool.retry_operation_sync(update_investor_in_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 