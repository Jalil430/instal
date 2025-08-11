import json
import os
import ydb
import jwt
import logging
from typing import Union, Optional, Tuple
from decimal import Decimal
from datetime import datetime, date

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
        logger.info(f"Received search request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        # Get search parameters from query string - enforce user_id from JWT
        query_params = event.get('queryStringParameters') or {}
        client_id = query_params.get('client_id')
        investor_id = query_params.get('investor_id')
        product_name = query_params.get('product_name')
        installment_number = query_params.get('installment_number')
        
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
            # Build dynamic WHERE clause - always include user_id for security
            where_conditions = ["user_id = $user_id"]
            params = {'$user_id': user_id}
            
            if client_id:
                where_conditions.append("client_id = $client_id")
                params['$client_id'] = client_id
                
            if investor_id:
                where_conditions.append("investor_id = $investor_id")
                params['$investor_id'] = investor_id
                
            if product_name:
                where_conditions.append("product_name LIKE $product_name")
                params['$product_name'] = f"%{product_name}%"
            if installment_number:
                where_conditions.append("installment_number = $installment_number")
                params['$installment_number'] = int(installment_number)
            
            where_clause = ""
            if where_conditions:
                where_clause = "WHERE " + " AND ".join(where_conditions)
            
            # Declare parameters - always include user_id
            declare_statements = ["DECLARE $user_id AS Utf8;"]
            if client_id:
                declare_statements.append("DECLARE $client_id AS Utf8;")
            if investor_id:
                declare_statements.append("DECLARE $investor_id AS Utf8;")
            if product_name:
                declare_statements.append("DECLARE $product_name AS Utf8;")
            if installment_number:
                declare_statements.append("DECLARE $installment_number AS Int32;")
            
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
                installment_number,
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