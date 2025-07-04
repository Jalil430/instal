import json
import os
import ydb
import hmac
import logging
from typing import Union
from decimal import Decimal
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
    try:
        logger.info(f"Received search request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        # Get search parameters from query string
        query_params = event.get('queryStringParameters') or {}
        user_id = query_params.get('user_id')
        client_id = query_params.get('client_id')
        investor_id = query_params.get('investor_id')
        product_name = query_params.get('product_name')
        
        # Database connection
        endpoint = os.environ['YDB_ENDPOINT']
        database = os.environ['YDB_DATABASE']
        
        driver_config = ydb.DriverConfig(
            endpoint=endpoint,
            database=database,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True)
        
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            # Build dynamic WHERE clause
            where_conditions = []
            params = {}
            
            if user_id:
                where_conditions.append("user_id = $user_id")
                params['$user_id'] = user_id
            
            if client_id:
                where_conditions.append("client_id = $client_id")
                params['$client_id'] = client_id
                
            if investor_id:
                where_conditions.append("investor_id = $investor_id")
                params['$investor_id'] = investor_id
                
            if product_name:
                where_conditions.append("product_name LIKE $product_name")
                params['$product_name'] = f"%{product_name}%"
            
            where_clause = ""
            if where_conditions:
                where_clause = "WHERE " + " AND ".join(where_conditions)
            
            # Declare parameters
            declare_statements = []
            if user_id:
                declare_statements.append("DECLARE $user_id AS Utf8;")
            if client_id:
                declare_statements.append("DECLARE $client_id AS Utf8;")
            if investor_id:
                declare_statements.append("DECLARE $investor_id AS Utf8;")
            if product_name:
                declare_statements.append("DECLARE $product_name AS Utf8;")
            
            query = f"""
            {' '.join(declare_statements)}
            
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
            {where_clause}
            ORDER BY created_at DESC;
            """
            
            prepared_query = session.prepare(query)
            result_sets = session.transaction().execute(
                prepared_query,
                params,
                commit_tx=True
            )
            
            return result_sets[0]
        
        result_set = pool.retry_operation_sync(execute_query)
        
        def convert_timestamp(ts):
            if ts is None: return None
            return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else ts.isoformat()

        def convert_date(d):
            if d is None: return None
            if isinstance(d, date): return d.strftime('%Y-%m-%d')
            if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal()).strftime('%Y-%m-%d')
            return str(d)
        
        installments = []
        for row in result_set.rows:
            installment = {
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
            }
            installments.append(installment)
        
        driver.stop()
        
        logger.info(f"Found {len(installments)} installments matching search criteria")
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps(installments)
        }
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'error': 'Internal server error'})
        } 