import os
import json
import ydb
import jwt
import logging
from datetime import datetime
from typing import Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# YDB connection configuration
YDB_ENDPOINT = os.environ.get('YDB_ENDPOINT')
YDB_DATABASE = os.environ.get('YDB_DATABASE')

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
    Checks the subscription status for a user.
    
    Expected request body:
    {
        "user_id": "user_id"
    }
    
    Returns:
    {
        "success": true,
        "subscriptions": [
            {
                "code": "...",
                "subscription_type": "...",
                "duration": "...",
                "user_telegram": "...",
                "amount": 0.0,
                "created_date": "...",
                "activated_date": "...",
                "end_date": "...",
                "status": "active",
                "activated_by": "user_id"
            }
        ]
    }
    
    Or error response:
    {
        "success": false,
        "error": {
            "code": "ERROR_CODE",
            "message": "Error message"
        }
    }
    """
    
    try:
        # Authenticate request using JWTAuth class
        user_id_from_token, auth_error = JWTAuth.authenticate_request(event)
        if auth_error:
            return error_response('UNAUTHORIZED', auth_error)
        
        # Parse request body
        if 'body' not in event:
            return error_response('INVALID_REQUEST', 'Request body is required')
        
        try:
            body = json.loads(event['body'])
        except json.JSONDecodeError:
            return error_response('INVALID_REQUEST', 'Invalid JSON in request body')
        
        # Validate required fields
        user_id = body.get('user_id', '').strip()
        
        if not user_id:
            return error_response('INVALID_REQUEST', 'User ID is required')
        
        # Ensure the authenticated user matches the requested user_id
        if user_id_from_token != user_id:
            return error_response('FORBIDDEN', 'Cannot check subscription for another user')
        
        # Validate YDB configuration
        if not YDB_ENDPOINT or not YDB_DATABASE:
            logger.error("YDB configuration missing: YDB_ENDPOINT or YDB_DATABASE is not set")
            return error_response('SERVER_ERROR', 'Server configuration error')

        # Connect to YDB using metadata credentials
        driver_config = ydb.DriverConfig(
            endpoint=YDB_ENDPOINT,
            database=YDB_DATABASE,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True, timeout=5)
        
        try:
            with ydb.SessionPool(driver) as pool:
                result = check_user_subscriptions(pool, user_id)
                return result
        finally:
            driver.stop()
            
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        print(f"Error type: {type(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return error_response('SERVER_ERROR', f'Internal server error: {str(e)}')

def check_user_subscriptions(pool, user_id):
    """Checks all subscription codes for a user and updates expired ones"""
    
    def callee(session):
        def _s(val):
            return val.decode('utf-8') if isinstance(val, (bytes, bytearray)) else val
        def _dt(val):
            if val is None:
                return None
            # If already datetime/date-like
            if hasattr(val, 'isoformat'):
                return val
            # If timestamp number (guess secs/millis)
            if isinstance(val, (int, float)):
                try:
                    from datetime import datetime
                    # microseconds
                    if val > 1e14:
                        return datetime.utcfromtimestamp(val / 1_000_000.0)
                    # milliseconds
                    if val > 1e12:
                        return datetime.utcfromtimestamp(val / 1000.0)
                    if val > 1e9:
                        return datetime.utcfromtimestamp(val)
                    return datetime.utcfromtimestamp(val)
                except Exception:
                    return None
            return None
        def _iso(val):
            dv = _dt(val)
            if dv is not None:
                return dv.isoformat()
            if isinstance(val, (bytes, bytearray)):
                try:
                    return val.decode('utf-8')
                except Exception:
                    return str(val)
            return str(val) if val is not None else None
        # Get all subscription codes for the user
        query = """
        DECLARE $user_id AS Utf8;
        SELECT code, subscription_type, duration, user_telegram, amount, 
               created_date, activated_date, end_date, status, activated_by
        FROM subscription_codes
        WHERE activated_by = $user_id;
        """
        
        prepared_query = session.prepare(query)
        result_sets = session.transaction().execute(
            prepared_query,
            {'$user_id': user_id},
            commit_tx=False
        )
        
        subscriptions = []
        server_time = datetime.utcnow()
        codes_to_expire = []
        
        for row in result_sets[0].rows:
            status_val = _s(row.status)
            end_dt = _dt(row.end_date)
            subscription_data = {
                'code': _s(row.code),
                'subscription_type': _s(row.subscription_type),
                'duration': _s(row.duration),
                'user_telegram': _s(row.user_telegram) if row.user_telegram else None,
                'amount': float(row.amount),
                'created_date': _iso(row.created_date),
                'activated_date': _iso(row.activated_date) if row.activated_date else None,
                'end_date': _iso(row.end_date) if row.end_date else None,
                'status': status_val,
                'activated_by': _s(row.activated_by) if row.activated_by else None
            }
            
            # Check if active subscription has expired based on server time
            if (status_val == 'active' and 
                end_dt and 
                end_dt < server_time):
                
                # Mark for expiration
                codes_to_expire.append(_s(row.code))
                subscription_data['status'] = 'expired'
            
            subscriptions.append(subscription_data)
        
        # Update expired codes in the database
        if codes_to_expire:
            for code in codes_to_expire:
                update_query = """
                DECLARE $code AS Utf8;
                DECLARE $status AS Utf8;
                UPDATE subscription_codes
                SET status = $status
                WHERE code = $code;
                """
                
                prepared_update = session.prepare(update_query)
                session.transaction().execute(
                    prepared_update,
                    {
                        '$code': code,
                        '$status': 'expired'
                    },
                    commit_tx=True
                )
        
        # Return the subscription data
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps({
                'success': True,
                'subscriptions': subscriptions
            })
        }
    
    return pool.retry_operation_sync(callee)

def error_response(error_code, message, status_code=400):
    """Returns a standardized error response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        'body': json.dumps({
            'success': False,
            'error': {
                'code': error_code,
                'message': message
            }
        })
    }