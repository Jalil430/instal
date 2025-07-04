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
    """Handles input validation"""
    
    @staticmethod
    def validate_investor_id(investor_id: str) -> tuple[str, Optional[str]]:
        """Validate and sanitize investor ID"""
        if not investor_id:
            return None, "Investor ID is required"
        
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, investor_id.lower()):
            return None, "Invalid investor ID format"
        
        return investor_id.lower(), None

class ApiKeyAuth:
    """Handles API key authentication"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        """Validate API key from request headers"""
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured")
            return False
        
        headers = event.get('headers', {})
        api_key = headers.get('x-api-key') or headers.get('X-Api-Key')
        if not api_key:
            logger.warning("No API key in request")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function to retrieve an investor by ID.
    """
    try:
        logger.info(f"Received GET request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized access")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        path_params = event.get('pathParameters', {})
        investor_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_investor_id(investor_id)
        
        if validation_error:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': validation_error})}
        
        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)
            
            def get_investor(session):
                query = """
                DECLARE $investor_id AS Utf8;
                SELECT id, user_id, full_name, investment_amount, investor_percentage, user_percentage, created_at, updated_at
                FROM investors 
                WHERE id = $investor_id;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    {'$investor_id': sanitized_id},
                    commit_tx=True
                )
                
                if not result_sets[0].rows:
                    logger.info(f"Investor not found: {sanitized_id}")
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Investor not found'})}
                
                row = result_sets[0].rows[0]
                
                def convert_timestamp(ts):
                    if ts is None: return None
                    return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else ts.isoformat()

                investor_data = {
                    'id': row.id,
                    'user_id': row.user_id,
                    'full_name': row.full_name,
                    'investment_amount': float(row.investment_amount),
                    'investor_percentage': float(row.investor_percentage),
                    'user_percentage': float(row.user_percentage),
                    'created_at': convert_timestamp(row.created_at),
                    'updated_at': convert_timestamp(row.updated_at)
                }
                
                logger.info(f"Investor retrieved: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(investor_data)}
            
            return pool.retry_operation_sync(get_investor)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 