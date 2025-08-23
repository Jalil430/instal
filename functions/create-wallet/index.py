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
        """Validate and sanitize wallet input data"""
        errors = []
        sanitized = {}
        
        # Define validation rules
        validation_rules = {
            'name': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 100,
            },
            'type': {
                'required': True,
                'type': str,
                'allowed_values': ['personal', 'investor'],
            },
            'currency': {
                'required': False,
                'type': str,
                'default': 'RUB',
                'allowed_values': ['RUB'],
            },
            'initial_balance_minor_units': {
                'required': False,
                'type': int,
                'min_value': 0,
                'default': 0,
            },
            # Investor-specific fields
            'investment_amount_minor_units': {
                'required': False,
                'type': int,
                'min_value': 1,
            },
            'investor_percentage': {
                'required': False,
                'type': (int, float),
                'min_value': 0.0,
                'max_value': 100.0,
            },
            'user_percentage': {
                'required': False,
                'type': (int, float),
                'min_value': 0.0,
                'max_value': 100.0,
            },
            'investment_return_date': {
                'required': False,
                'type': str,
            },
        }
        
        wallet_type = data.get('type')
        
        for field, rules in validation_rules.items():
            value = data.get(field)
            
            # Handle default values
            if value is None and 'default' in rules:
                value = rules['default']
            
            # Check if required field is present
            if rules['required'] and (value is None or value == ''):
                errors.append(f'{field} is required')
                continue
            
            # Skip validation for optional empty fields
            if not rules['required'] and (value is None or value == ''):
                if field in ['investment_amount_minor_units', 'investor_percentage', 'user_percentage', 'investment_return_date']:
                    sanitized[field] = None
                else:
                    sanitized[field] = rules.get('default')
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
                
                # Allowed values validation
                if 'allowed_values' in rules and value not in rules['allowed_values']:
                    errors.append(f'{field} must be one of: {", ".join(rules["allowed_values"])}')
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
        
        # Investor wallet specific validations
        if wallet_type == 'investor':
            required_investor_fields = ['investment_amount_minor_units', 'investor_percentage', 'user_percentage', 'investment_return_date']
            for field in required_investor_fields:
                if field not in sanitized or sanitized[field] is None:
                    errors.append(f'{field} is required for investor wallets')
            
            # Validate percentages sum to 100
            if 'investor_percentage' in sanitized and 'user_percentage' in sanitized:
                if sanitized['investor_percentage'] is not None and sanitized['user_percentage'] is not None:
                    total_percentage = sanitized['investor_percentage'] + sanitized['user_percentage']
                    if abs(total_percentage - 100.0) > 0.01:  # Allow small floating point errors
                        errors.append('Investor and user percentages must sum to 100%')
            
            # Validate return date format and future date
            if 'investment_return_date' in sanitized and sanitized['investment_return_date']:
                try:
                    return_date = datetime.fromisoformat(sanitized['investment_return_date'].replace('Z', '+00:00'))
                    if return_date <= datetime.now():
                        errors.append('Investment return date must be in the future')
                except ValueError:
                    errors.append('Investment return date must be in ISO format (YYYY-MM-DD)')
        
        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to create a new wallet
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Received wallet creation request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
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
            
            def create_wallet_and_balance(session):
                # Generate IDs
                wallet_id = str(uuid.uuid4())
                current_time = datetime.utcnow()
                
                # Prepare wallet data
                wallet_data = {
                    '$id': wallet_id,
                    '$user_id': user_id,
                    '$name': sanitized_data['name'],
                    '$type': sanitized_data['type'],
                    '$currency': sanitized_data['currency'],
                    '$status': 'active',
                    '$require_nonnegative': True,
                    '$allow_partial_allocation': False,
                    '$created_at': current_time,
                    '$updated_at': current_time,
                }
                
                # Add investor-specific fields
                if sanitized_data['type'] == 'investor':
                    wallet_data.update({
                        '$investment_amount_minor_units': sanitized_data['investment_amount_minor_units'],
                        '$investor_percentage': sanitized_data['investor_percentage'],
                        '$user_percentage': sanitized_data['user_percentage'],
                        '$investment_return_date': datetime.fromisoformat(sanitized_data['investment_return_date'].replace('Z', '+00:00')).date(),
                    })
                    initial_balance = sanitized_data['investment_amount_minor_units']
                else:
                    wallet_data.update({
                        '$investment_amount_minor_units': None,
                        '$investor_percentage': None,
                        '$user_percentage': None,
                        '$investment_return_date': None,
                    })
                    initial_balance = sanitized_data['initial_balance_minor_units']
                
                # Create wallet
                wallet_query = """
                DECLARE $id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $name AS Utf8;
                DECLARE $type AS Utf8;
                DECLARE $currency AS Utf8;
                DECLARE $status AS Utf8;
                DECLARE $require_nonnegative AS Bool;
                DECLARE $allow_partial_allocation AS Bool;
                DECLARE $investment_amount_minor_units AS Int64?;
                DECLARE $investor_percentage AS Decimal(5,2)?;
                DECLARE $user_percentage AS Decimal(5,2)?;
                DECLARE $investment_return_date AS Date?;
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;
                
                INSERT INTO wallets (
                  id, user_id, name, type, currency, status,
                  require_nonnegative, allow_partial_allocation,
                  investment_amount_minor_units, investor_percentage, user_percentage, investment_return_date,
                  created_at, updated_at
                ) 
                VALUES (
                  $id, $user_id, $name, $type, $currency, $status,
                  $require_nonnegative, $allow_partial_allocation,
                  $investment_amount_minor_units, $investor_percentage, $user_percentage, $investment_return_date,
                  $created_at, $updated_at
                );
                """
                
                prepared_wallet = session.prepare(wallet_query)
                session.transaction().execute(prepared_wallet, wallet_data, commit_tx=True)
                
                # Create wallet balance
                balance_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $balance_minor_units AS Int64;
                DECLARE $version AS Uint64;
                DECLARE $updated_at AS Timestamp;
                
                INSERT INTO wallet_balances (
                  wallet_id, user_id, balance_minor_units, version, updated_at
                ) 
                VALUES (
                  $wallet_id, $user_id, $balance_minor_units, $version, $updated_at
                );
                """
                
                balance_data = {
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$balance_minor_units': initial_balance,
                    '$version': 1,
                    '$updated_at': current_time,
                }
                
                prepared_balance = session.prepare(balance_query)
                session.transaction().execute(prepared_balance, balance_data, commit_tx=True)
                
                # Create initial transaction if there's a starting balance
                if initial_balance > 0:
                    transaction_id = str(uuid.uuid4())
                    reference_type = 'initial_investment' if sanitized_data['type'] == 'investor' else 'adjustment'
                    description = f'Initial {"investment" if sanitized_data["type"] == "investor" else "balance"}: {initial_balance / 100:.2f} RUB'
                    
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
                        '$amount_minor_units': initial_balance,
                        '$currency': sanitized_data['currency'],
                        '$reference_type': reference_type,
                        '$reference_id': None,
                        '$group_id': None,
                        '$correlation_id': None,
                        '$description': description,
                        '$created_by': user_id,
                        '$created_at': current_time,
                    }
                    
                    prepared_transaction = session.prepare(transaction_query)
                    session.transaction().execute(prepared_transaction, transaction_data, commit_tx=True)
                
                logger.info(f"Wallet created successfully: {wallet_id}")
                return {
                    'statusCode': 201,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'id': wallet_id})
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(create_wallet_and_balance)
            
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