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
        logger.info(f"Received update payment request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
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
            # First, verify the payment belongs to an installment owned by the authenticated user
            verify_query = """
            DECLARE $payment_id AS Utf8;
            DECLARE $user_id AS Utf8;
            SELECT ip.id 
            FROM installment_payments ip
            JOIN installments i ON ip.installment_id = i.id
            WHERE ip.id = $payment_id AND i.user_id = $user_id;
            """
            
            verify_result = session.transaction().execute(
                session.prepare(verify_query),
                {'$payment_id': payment_id, '$user_id': user_id},
                commit_tx=False
            )
            
            if not verify_result[0].rows:
                raise Exception("Payment not found or access denied")
            
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