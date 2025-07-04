import os
import json
import ydb
import re
import hmac
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecurityValidator:
    """Handles input validation and sanitization"""
    
    @staticmethod
    def validate_client_id(client_id: str) -> tuple[str, str | None]:
        """Validate and sanitize client ID"""
        if not client_id:
            return None, "Client ID is required"
        
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, client_id.lower()):
            return None, "Invalid client ID format"
        
        return client_id.lower(), None

class ApiKeyAuth:
    """Handles API key authentication"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        """Validate API key from request headers"""
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured in environment")
            return False
        
        headers = event.get('headers', {})
        api_key = None
        for key, value in headers.items():
            if key.lower() == 'x-api-key':
                api_key = value
                break
        
        if not api_key:
            logger.warning("No API key provided in request")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function handler to delete a client by ID.
    """
    try:
        logger.info(f"Received delete request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized access attempt")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})}
        
        path_params = event.get('pathParameters', {})
        client_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_client_id(client_id)
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

            def delete_client_from_db(session):
                tx = session.transaction(ydb.SerializableReadWrite())
                
                # Check if client exists
                check_query = "DECLARE $client_id AS Utf8; SELECT id FROM clients WHERE id = $client_id;"
                prepared_check = session.prepare(check_query)
                result_sets = tx.execute(prepared_check, {'$client_id': sanitized_id})
                
                if not result_sets[0].rows:
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Client not found'})}

                # Delete client by ID
                delete_query = "DECLARE $client_id AS Utf8; DELETE FROM clients WHERE id = $client_id;"
                prepared_delete = session.prepare(delete_query)
                tx.execute(prepared_delete, {'$client_id': sanitized_id})
                
                tx.commit()

                logger.info(f"Client deleted successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Client deleted successfully'})}

            result = pool.retry_operation_sync(delete_client_from_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 