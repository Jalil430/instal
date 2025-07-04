import os
import json
import ydb
import hmac
import logging
from datetime import datetime, date

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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
    Yandex Cloud Function handler to list installments with pagination.
    """
    try:
        logger.info(f"Received list request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        query_params = event.get('queryStringParameters', {}) or {}
        try:
            limit = int(query_params.get('limit', 10))
            offset = int(query_params.get('offset', 0))
        except (ValueError, TypeError):
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid limit or offset'})}

        if not (0 < limit <= 100):
             return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Limit must be between 1 and 100'})}
        if offset < 0:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Offset must be non-negative'})}

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def list_installments_from_db(session):
                query = """
                DECLARE $limit AS Uint64;
                DECLARE $offset AS Uint64;
                SELECT 
                    id,
                    user_id,
                    client_id,
                    investor_id,
                    product_name,
                    cash_price,
                    installment_price,
                    down_payment,
                    term_months,
                    down_payment_date,
                    installment_start_date,
                    installment_end_date,
                    monthly_payment,
                    created_at,
                    updated_at
                FROM installments
                ORDER BY created_at DESC
                LIMIT $limit OFFSET $offset;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    {'$limit': limit, '$offset': offset},
                    commit_tx=True
                )
                
                installments = []
                for row in result_sets[0].rows:
                    def convert_timestamp(ts):
                        if ts is None: return None
                        return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else ts.isoformat()

                    def convert_date(d):
                        if d is None: return None
                        if isinstance(d, date): return d.strftime('%Y-%m-%d')
                        if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal()).strftime('%Y-%m-%d')
                        return str(d)

                    installments.append({
                        'id': row.id,
                        'user_id': row.user_id,
                        'client_id': row.client_id,
                        'investor_id': row.investor_id,
                        'product_name': row.product_name,
                        'cash_price': float(row.cash_price),
                        'installment_price': float(row.installment_price),
                        'down_payment': float(row.down_payment),
                        'term_months': row.term_months,
                        'down_payment_date': convert_date(row.down_payment_date),
                        'installment_start_date': convert_date(row.installment_start_date),
                        'installment_end_date': convert_date(row.installment_end_date),
                        'monthly_payment': float(row.monthly_payment),
                        'created_at': convert_timestamp(row.created_at),
                        'updated_at': convert_timestamp(row.updated_at)
                    })
                
                logger.info(f"Listed {len(installments)} installments.")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(installments)}

            return pool.retry_operation_sync(list_installments_from_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 