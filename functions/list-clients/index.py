import os
import json
import ydb
import hmac
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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
    Yandex Cloud Function handler to list clients with pagination.
    """
    try:
        logger.info(f"Received list request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized access attempt")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})}
        
        query_params = event.get('queryStringParameters', {}) or {}
        try:
            limit = int(query_params.get('limit', 10))
            offset = int(query_params.get('offset', 0))
        except (ValueError, TypeError):
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid limit or offset. Must be integers.'})}

        if not (0 < limit <= 100):
             return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Limit must be between 1 and 100.'})}
        if offset < 0:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Offset must be a non-negative number.'})}

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def list_clients_from_db(session):
                query = """
                DECLARE $limit AS Uint64;
                DECLARE $offset AS Uint64;
                SELECT id, user_id, full_name, contact_number, passport_number, address, created_at, updated_at
                FROM clients
                ORDER BY created_at DESC
                LIMIT $limit OFFSET $offset;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                    prepared_query,
                    {'$limit': limit, '$offset': offset},
                    commit_tx=True
                )
                
                clients = []
                for row in result_sets[0].rows:
                    def convert_timestamp(ts):
                        if ts is None: return None
                        return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else (ts.isoformat() if hasattr(ts, 'isoformat') else str(ts))

                    clients.append({
                        'id': row.id,
                        'user_id': row.user_id,
                        'full_name': row.full_name,
                        'contact_number': row.contact_number,
                        'passport_number': row.passport_number,
                        'address': row.address,
                        'created_at': convert_timestamp(row.created_at),
                        'updated_at': convert_timestamp(row.updated_at)
                    })
                
                logger.info(f"Listed {len(clients)} clients.")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(clients)}

            result = pool.retry_operation_sync(list_clients_from_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 