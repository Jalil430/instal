import os
import json
import ydb
import re
import hmac
import logging
from datetime import datetime
from typing import Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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

def handler(event, context):
    """
    Yandex Cloud Function handler to retrieve a client by ID with enhanced security.
    """
    try:
        # Log request (without sensitive data)
        logger.info(f"Received GET request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. API Key Authentication
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized access attempt")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})
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
                # Get client by ID
                query = """
                DECLARE $client_id AS Utf8;
                SELECT id, user_id, full_name, contact_number, passport_number, address, created_at, updated_at
                FROM clients 
                WHERE id = $client_id;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    {'$client_id': sanitized_id},
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