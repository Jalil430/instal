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
        logger.info(f"Received update payment request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        # Get payment ID from path parameters
        payment_id = event['pathParameters']['id']
        
        # Parse request body
        try:
            raw_body = event.get('body', '{}')
            
            # Check if the body is Base64 encoded (common with Yandex Cloud Functions)
            try:
                # Try to decode as Base64 first
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                # If Base64 decoding fails, try parsing as plain JSON
                body = json.loads(raw_body)
        except json.JSONDecodeError:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON in request body'})}
        
        # --- Validation ---
        if 'is_paid' not in body or not isinstance(body.get('is_paid'), bool):
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "'is_paid' (boolean) is a required field"})}

        is_paid = body['is_paid']
        paid_date = None

        if is_paid:
            if 'paid_date' not in body or not body['paid_date']:
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "'paid_date' is required when 'is_paid' is true"})}
            try:
                paid_date = datetime.strptime(body['paid_date'], '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "Invalid 'paid_date' format. Expected YYYY-MM-DD."})}

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
            query = """
            DECLARE $payment_id AS Utf8;
            DECLARE $is_paid AS Bool;
            DECLARE $paid_date AS Optional<Date>;
            DECLARE $updated_at AS Timestamp;
            
            UPDATE installment_payments
            SET 
                is_paid = $is_paid,
                paid_date = $paid_date,
                updated_at = $updated_at
            WHERE id = $payment_id;
            """
            
            prepared_query = session.prepare(query)
            session.transaction().execute(
                prepared_query,
                {
                    '$payment_id': payment_id,
                    '$is_paid': is_paid,
                    '$paid_date': paid_date,
                    '$updated_at': datetime.utcnow()
                },
                commit_tx=True
            )
        
        try:
            pool.retry_operation_sync(execute_query)
        finally:
            driver.stop()
        
        logger.info(f"Updated installment payment: {payment_id}")
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'message': 'Installment payment updated successfully'})
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