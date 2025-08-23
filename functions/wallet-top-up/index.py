import os
import json
import uuid
import ydb
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
        """Validate and sanitize top-up input data"""
        errors = []
        sanitized = {}
        
        # Define validation rules
        validation_rules = {
            'amount_minor_units': {
                'required': True,
                'type': int,
                'min_value': 1,
            },
            'description': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 500,
            },
            'reference_id': {
                'required': False,
                'type': str,
                'max_length': 100,
            },
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
                errors.append(f'{field} must be of correct type')
                continue
            
            # String validations
            if isinstance(value, str):
                # Length validation
                if 'min_length' in rules and len(value) < rules['min_length']:
                    errors.append(f'{field} must be at least {rules["min_length"]} characters')
                    continue
                
                if 'max_length' in rules and len(value) > rules['max_length']:
                    errors.append(f'{field} must be no more than {rules["max_length"]} characters')
                    continue
                
                # Sanitize string
                sanitized[field] = value.strip()
            
            # Numeric validations
            elif isinstance(value, (int, float)):
                if 'min_value' in rules and value < rules['min_value']:
                    errors.append(f'{field} must be at least {rules["min_value"]}')
                    continue
                
                if 'max_value' in rules and value > rules['max_value']:
                    errors.append(f'{field} must be no more than {rules["max_value"]}')
                    continue
                
                sanitized[field] = value
            else:
                sanitized[field] = value
        
        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to add funds to a wallet (top-up)
    """
    try:
        # Log request
        logger.info(f"Received wallet top-up request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Extract wallet ID from path
        path_parameters = event.get('pathParameters') or {}
        wallet_id = path_parameters.get('id')
        
        if not wallet_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Wallet ID is required'})
            }
        
        # 3. Parse and validate request body
        try:
            raw_body = event.get('body', '{}')
            
            # Check if the body is Base64 encoded
            try:
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
        
        # 4. Input validation and sanitization
        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        
        if validation_errors:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})
            }
        
        # 5. Database operations
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
            
            def top_up_wallet(session):
                # First, verify wallet exists and belongs to user
                wallet_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                
                SELECT id, name, currency, status
                FROM wallets 
                WHERE id = $wallet_id AND user_id = $user_id;
                """
                
                prepared_wallet = session.prepare(wallet_query)
                wallet_result = session.transaction().execute(
                    prepared_wallet,
                    {'$wallet_id': wallet_id, '$user_id': user_id},
                    commit_tx=True
                )
                
                if not wallet_result[0].rows:
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet not found'})
                    }
                
                wallet_row = wallet_result[0].rows[0]
                if wallet_row['status'] != 'active':
                    return {
                        'statusCode': 400,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Cannot top up archived wallet'})
                    }
                
                # Get current balance for optimistic locking
                balance_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                
                SELECT balance_minor_units, version
                FROM wallet_balances 
                WHERE wallet_id = $wallet_id AND user_id = $user_id;
                """
                
                prepared_balance = session.prepare(balance_query)
                balance_result = session.transaction().execute(
                    prepared_balance,
                    {'$wallet_id': wallet_id, '$user_id': user_id},
                    commit_tx=True
                )
                
                if not balance_result[0].rows:
                    return {
                        'statusCode': 500,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet balance not found'})
                    }
                
                balance_row = balance_result[0].rows[0]
                current_balance = balance_row['balance_minor_units']
                current_version = balance_row['version']
                new_balance = current_balance + sanitized_data['amount_minor_units']
                
                # Create credit transaction
                transaction_id = str(uuid.uuid4())
                current_time = datetime.utcnow()
                
                transaction_query = """
                DECLARE $id AS Utf8;
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $direction AS Utf8;
                DECLARE $amount_minor_units AS Int64;
                DECLARE $currency AS Utf8;
                DECLARE $reference_type AS Utf8;
                DECLARE $reference_id AS Utf8?;
                DECLARE $group_id AS Utf8?;
                DECLARE $correlation_id AS Utf8?;
                DECLARE $description AS Utf8;
                DECLARE $created_by AS Utf8;
                DECLARE $created_at AS Timestamp;
                
                INSERT INTO ledger_transactions (
                  id, wallet_id, user_id, direction, amount_minor_units, currency,
                  reference_type, reference_id, group_id, correlation_id,
                  description, created_by, created_at
                ) 
                VALUES (
                  $id, $wallet_id, $user_id, $direction, $amount_minor_units, $currency,
                  $reference_type, $reference_id, $group_id, $correlation_id,
                  $description, $created_by, $created_at
                );
                """
                
                transaction_data = {
                    '$id': transaction_id,
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$direction': 'credit',
                    '$amount_minor_units': sanitized_data['amount_minor_units'],
                    '$currency': wallet_row['currency'],
                    '$reference_type': 'adjustment',
                    '$reference_id': sanitized_data.get('reference_id'),
                    '$group_id': None,
                    '$correlation_id': None,
                    '$description': sanitized_data['description'],
                    '$created_by': user_id,
                    '$created_at': current_time,
                }
                
                prepared_transaction = session.prepare(transaction_query)
                session.transaction().execute(prepared_transaction, transaction_data, commit_tx=True)
                
                # Update wallet balance with optimistic locking
                update_balance_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $new_balance AS Int64;
                DECLARE $new_version AS Uint64;
                DECLARE $expected_version AS Uint64;
                DECLARE $updated_at AS Timestamp;
                
                UPDATE wallet_balances 
                SET balance_minor_units = $new_balance, 
                    version = $new_version,
                    updated_at = $updated_at
                WHERE wallet_id = $wallet_id 
                  AND user_id = $user_id 
                  AND version = $expected_version;
                """
                
                balance_data = {
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$new_balance': new_balance,
                    '$new_version': current_version + 1,
                    '$expected_version': current_version,
                    '$updated_at': current_time,
                }
                
                prepared_update = session.prepare(update_balance_query)
                session.transaction().execute(prepared_update, balance_data, commit_tx=True)
                
                logger.info(f"Wallet {wallet_id} topped up with {sanitized_data['amount_minor_units']} minor units")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'transaction_id': transaction_id,
                        'new_balance_minor_units': new_balance,
                        'new_balance_rubles': new_balance / 100.0,
                        'amount_added_minor_units': sanitized_data['amount_minor_units'],
                        'amount_added_rubles': sanitized_data['amount_minor_units'] / 100.0,
                    })
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(top_up_wallet)
            
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
        # Generic error handler
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }