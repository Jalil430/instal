import json
import os
import ydb
import jwt
import logging
from typing import Union, Optional, Tuple
from decimal import Decimal
from datetime import datetime, date, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class JWTAuth:
    """Handles JWT token authentication and validation"""
    
    @staticmethod
    def verify_jwt_token(token: str, token_type: str = 'access') -> dict:
        """Verify and decode JWT token"""
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            
            # Check token type
            if payload.get('type') != token_type:
                raise ValueError(f"Invalid token type. Expected {token_type}")
            
            return payload
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid token")
    
    @staticmethod
    def extract_token_from_event(event: dict) -> Optional[str]:
        """Extract JWT token from Authorization header"""
        headers = event.get('headers', {})
        
        # Handle case-insensitive headers
        auth_header = None
        for key, value in headers.items():
            if key.lower() == 'authorization':
                auth_header = value
                break
        
        if not auth_header:
            return None
        
        # Extract token from Bearer header
        if not auth_header.startswith('Bearer '):
            return None
        
        return auth_header[7:]  # Remove 'Bearer ' prefix
    
    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        """
        Authenticate request and return user_id and error message
        Returns: (user_id, error_message)
        """
        try:
            # Extract JWT token
            token = JWTAuth.extract_token_from_event(event)
            
            if not token:
                return None, "Authorization header missing or invalid format"
            
            # Verify token
            payload = JWTAuth.verify_jwt_token(token, 'access')
            user_id = payload.get('user_id')
            
            if not user_id:
                return None, "Invalid token: user_id not found"
            
            logger.info(f"Request authenticated for user: {payload.get('email', 'unknown')}")
            return user_id, None
            
        except ValueError as e:
            return None, f"Authentication failed: {str(e)}"
        except Exception as e:
            logger.error(f"Unexpected authentication error: {e}")
            return None, "Authentication error"

def handler(event, context):
    try:
        logger.info(f"Received get request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
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
            # Query for the main installment details - filter by user_id for security
            installment_query = """
                DECLARE $installment_id AS Utf8;
                DECLARE $user_id AS Utf8;
                SELECT id, user_id, client_id, investor_id, product_name, cash_price, 
                       installment_price, down_payment, term_months, down_payment_date, 
                       installment_start_date, installment_end_date, monthly_payment, 
                       installment_number,
                       created_at, updated_at
                FROM installments WHERE id = $installment_id AND user_id = $user_id;
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
                {'$installment_id': installment_id, '$user_id': user_id}
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
                'installment_number': getattr(row, 'installment_number', None),
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