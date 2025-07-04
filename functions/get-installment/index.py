import json
import os
import ydb
import hmac
import logging
from typing import Union
from decimal import Decimal
from datetime import datetime, date, timedelta

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
        logger.info(f"Received get request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        # Get installment ID from path parameters
        installment_id = event['pathParameters']['id']
        
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
            # Query for the main installment details
            installment_query = """
                DECLARE $installment_id AS Utf8;
                SELECT id, user_id, client_id, investor_id, product_name, cash_price, 
                       installment_price, down_payment, term_months, down_payment_date, 
                       installment_start_date, installment_end_date, monthly_payment, 
                       created_at, updated_at
                FROM installments WHERE id = $installment_id;
            """
            
            # Query for the associated payments
            payments_query = """
                DECLARE $installment_id AS Utf8;
                SELECT id, installment_id, payment_number, due_date, expected_amount, 
                       is_paid, paid_date, created_at, updated_at
                FROM installment_payments WHERE installment_id = $installment_id
                ORDER BY payment_number;
            """

            tx = session.transaction(ydb.SerializableReadWrite())
            
            # Execute both queries
            installment_result_sets = tx.execute(
                session.prepare(installment_query),
                {'$installment_id': installment_id}
            )
            
            payments_result_sets = tx.execute(
                session.prepare(payments_query),
                {'$installment_id': installment_id}
            )

            tx.commit()
            
            return installment_result_sets[0], payments_result_sets[0]

        try:
            installment_result, payments_result = pool.retry_operation_sync(execute_query)
            
            if not installment_result.rows:
                return {
                    'statusCode': 404,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Installment not found'})
                }
            
            row = installment_result.rows[0]

            def convert_timestamp(ts):
                if ts is None: return None
                return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else (ts.isoformat() if hasattr(ts, 'isoformat') else str(ts))

            def convert_date(d):
                if d is None: return None
                if isinstance(d, datetime): return d.strftime('%Y-%m-%d')
                if isinstance(d, date): return d.strftime('%Y-%m-%d')
                # YDB Date type can be represented as days from epoch
                if isinstance(d, int): return (date(1970, 1, 1) + timedelta(days=d)).strftime('%Y-%m-%d')
                return str(d)

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
                'updated_at': convert_timestamp(row.updated_at),
                'payments': []
            }
            
            # Append payments to the installment object
            for payment_row in payments_result.rows:
                installment['payments'].append({
                    'id': payment_row.id,
                    'installment_id': payment_row.installment_id,
                    'payment_number': payment_row.payment_number,
                    'due_date': convert_date(payment_row.due_date),
                    'expected_amount': float(payment_row.expected_amount),
                    'is_paid': payment_row.is_paid,
                    'paid_date': convert_date(payment_row.paid_date),
                    'created_at': convert_timestamp(payment_row.created_at),
                    'updated_at': convert_timestamp(payment_row.updated_at)
                })

        finally:
            driver.stop()
        
        return {
            'statusCode': 200,
            'headers': { 'Content-Type': 'application/json' },
            'body': json.dumps(installment)
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