import os
import json
import ydb
import re
import hmac
import logging
from typing import Union

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecurityValidator:
    """Handles input validation"""
    
    @staticmethod
    def validate_investor_id(investor_id: str) -> tuple[Union[str, None], Union[str, None]]:
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
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured")
            return False
        
        headers = event.get('headers', {})
        api_key = headers.get('x-api-key') or headers.get('X-Api-Key')
        if not api_key:
            logger.warning("No API key provided")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function handler to delete an investor by ID.
    """
    try:
        logger.info(f"Received delete request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
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

            def delete_investor_from_db(session):
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

                # Delete the investor
                delete_query = """
                DECLARE $investor_id AS Utf8;
                DELETE FROM investors WHERE id = $investor_id;
                """
                prepared_delete = session.prepare(delete_query)
                session.transaction().execute(
                    prepared_delete, 
                    {'$investor_id': sanitized_id}, 
                    commit_tx=True
                )

                logger.info(f"Investor deleted successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Investor deleted successfully'})}

            return pool.retry_operation_sync(delete_investor_from_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 