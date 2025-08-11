import os
import json
import ydb
import re
import hmac
import jwt
import logging
from datetime import datetime
from typing import Optional, Tuple

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

def handler(event, context):
    """
    Yandex Cloud Function handler to retrieve a client by ID with enhanced security.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Received GET request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Extract and validate client ID from path parameters
        path_params = event.get('pathParameters', {})
        client_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_client_id(client_id)
        
        if validation_error:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': validation_error})
            }
        
        # 3. Database operations with enhanced error handling
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
            
            def get_client(session):
                # Get client by ID for the authenticated user
                query = """
                DECLARE $client_id AS Utf8;
                DECLARE $user_id AS Utf8;
                SELECT id, user_id, full_name, contact_number, passport_number, address,
                       guarantor_full_name, guarantor_contact_number, guarantor_passport_number, guarantor_address,
                       created_at, updated_at
                FROM clients 
                WHERE id = $client_id AND user_id = $user_id;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    {'$client_id': sanitized_id, '$user_id': user_id},
                    commit_tx=True
                )
                
                if not result_sets[0].rows:
                    logger.info(f"Client not found: {sanitized_id}")
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Client not found'})
                    }
                
                # Convert result to dictionary
                row = result_sets[0].rows[0]
                
                # Helper function to convert timestamp
                def convert_timestamp(ts):
                    if ts is None:
                        return None
                    if isinstance(ts, int):
                        # YDB timestamp is in microseconds
                        return datetime.fromtimestamp(ts / 1000000).isoformat()
                    elif hasattr(ts, 'isoformat'):
                        return ts.isoformat()
                    else:
                        return str(ts)
                
                client_data = {
                    'id': row.id,
                    'user_id': row.user_id,
                    'full_name': row.full_name,
                    'contact_number': row.contact_number,
                    'passport_number': row.passport_number,
                    'address': row.address,
                    'guarantor_full_name': getattr(row, 'guarantor_full_name', None),
                    'guarantor_contact_number': getattr(row, 'guarantor_contact_number', None),
                    'guarantor_passport_number': getattr(row, 'guarantor_passport_number', None),
                    'guarantor_address': getattr(row, 'guarantor_address', None),
                    'created_at': convert_timestamp(row.created_at),
                    'updated_at': convert_timestamp(row.updated_at)
                }
                
                logger.info(f"Client retrieved successfully: {sanitized_id}")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(client_data)
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(get_client)
            
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