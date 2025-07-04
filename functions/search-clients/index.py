import os
import json
import ydb
import hmac
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ApiKeyAuth:
    @staticmethod
    def validate_api_key(event: dict) -> bool:
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
    try:
        logger.info(f"Received search request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        query_params = event.get('queryStringParameters', {}) or {}
        searchable_fields = ['full_name', 'passport_number', 'contact_number', 'user_id', 'address']
        
        search_criteria = {k: v for k, v in query_params.items() if k in searchable_fields and v}
        if not search_criteria:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'At least one search parameter is required'})}

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def search_clients_in_db(session):
                declarations = []
                where_clauses = []
                params = {}

                for field, value in search_criteria.items():
                    param_name = f'${field}'
                    declarations.append(f"DECLARE {param_name} AS Utf8;")
                    where_clauses.append(f"{field} LIKE {param_name}")
                    params[param_name] = f"%{value}%"

                query = f"""
                {' '.join(declarations)}
                SELECT id, user_id, full_name, contact_number, passport_number, address, created_at, updated_at
                FROM clients
                WHERE {' AND '.join(where_clauses)};
                """
                
                result_sets = session.transaction(ydb.SerializableReadWrite()).execute(query, params, commit_tx=True)
                
                clients = []
                for row in result_sets[0].rows:
                    def convert_timestamp(ts):
                        if ts is None: return None
                        return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else (ts.isoformat() if hasattr(ts, 'isoformat') else str(ts))

                    clients.append({
                        'id': row.id, 'user_id': row.user_id, 'full_name': row.full_name,
                        'contact_number': row.contact_number, 'passport_number': row.passport_number,
                        'address': row.address, 'created_at': convert_timestamp(row.created_at),
                        'updated_at': convert_timestamp(row.updated_at)
                    })
                
                logger.info(f"Found {len(clients)} clients matching criteria.")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(clients)}

            result = pool.retry_operation_sync(search_clients_in_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 