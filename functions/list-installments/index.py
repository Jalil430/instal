import os
import json
import ydb
import jwt
import logging
from datetime import datetime, date
from typing import Optional, Tuple

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
    """
    Yandex Cloud Function handler to list installments with pagination.
    """
    try:
        logger.info(f"Received list request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
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
                DECLARE $user_id AS Utf8;
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
                WHERE user_id = $user_id
                ORDER BY created_at DESC
                LIMIT $limit OFFSET $offset;
                """
                prepared_query = session.prepare(query)
                result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                    prepared_query,
                    {'$user_id': user_id, '$limit': limit, '$offset': offset},
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

            result = pool.retry_operation_sync(list_installments_from_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 