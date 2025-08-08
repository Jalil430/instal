import json
import os
from datetime import datetime, timedelta
import ydb
import jwt

# YDB connection configuration
YDB_ENDPOINT = os.environ.get('YDB_ENDPOINT')
YDB_DATABASE = os.environ.get('YDB_DATABASE')
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')

def handler(event, context):
    """
    Validates and activates a subscription code for a user.
    
    Expected request body:
    {
        "code": "subscription_code",
        "user_id": "user_id"
    }
    
    Returns:
    {
        "success": true,
        "subscription": {
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
        # Verify JWT token (case-insensitive header lookup)
        headers = event.get('headers', {}) or {}
        auth_header = ''
        for key, value in headers.items():
            if key.lower() == 'authorization':
                auth_header = value or ''
                break
        if not auth_header.startswith('Bearer '):
            return error_response('UNAUTHORIZED', 'Authorization token required')
        
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        try:
            decoded_token = jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
            authenticated_user_id = decoded_token.get('user_id')
        except jwt.InvalidTokenError:
            return error_response('UNAUTHORIZED', 'Invalid or expired token')
        
        # Parse request body
        if 'body' not in event:
            return error_response('INVALID_REQUEST', 'Request body is required')
        
        try:
            body = json.loads(event['body'])
        except json.JSONDecodeError:
            return error_response('INVALID_REQUEST', 'Invalid JSON in request body')
        
        # Validate required fields
        code = body.get('code', '').strip()
        user_id = body.get('user_id', '').strip()
        
        if not code:
            return error_response('INVALID_REQUEST', 'Subscription code is required')
        
        if not user_id:
            return error_response('INVALID_REQUEST', 'User ID is required')
        
        # Ensure the authenticated user matches the requested user_id
        if authenticated_user_id != user_id:
            return error_response('FORBIDDEN', 'Cannot activate code for another user')
        
        # Validate YDB configuration
        if not YDB_ENDPOINT or not YDB_DATABASE:
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
                print(f"ValidateSubCode: request user_id={user_id}, auth_user_id={authenticated_user_id}, code_prefix={code[:6]}***")
                result = validate_and_activate_code(pool, code, user_id)
                return result
        finally:
            driver.stop()
            
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return error_response('SERVER_ERROR', 'Internal server error occurred')

def validate_and_activate_code(pool, code, user_id):
    """Validates and activates a subscription code"""
    
    def callee(session):
        def _s(val):
            return val.decode('utf-8') if isinstance(val, (bytes, bytearray)) else val
        def _iso(val):
            if val is None:
                return None
            # Prefer native date/datetime
            if hasattr(val, 'isoformat'):
                return val.isoformat()
            # Decode bytes to string if needed
            if isinstance(val, (bytes, bytearray)):
                try:
                    return val.decode('utf-8')
                except Exception:
                    return str(val)
            # Heuristic for epoch values
            if isinstance(val, (int, float)):
                try:
                    # Treat >1e12 as milliseconds
                    from datetime import datetime
                    if val > 1e12:
                        return datetime.utcfromtimestamp(val / 1000.0).isoformat()
                    # Treat >1e9 as seconds
                    if val > 1e9:
                        return datetime.utcfromtimestamp(val).isoformat()
                    # Fallback: seconds
                    return datetime.utcfromtimestamp(val).isoformat()
                except Exception:
                    return str(val)
            # Fallback string cast
            return str(val)

        # First, check if the code exists and get its details
        query = """
        DECLARE $code AS Utf8;
        SELECT code, subscription_type, duration, user_telegram, amount, 
               created_date, activated_date, end_date, status, activated_by
        FROM subscription_codes
        WHERE code = $code;
        """
        
        prepared_query = session.prepare(query)
        result_sets = session.transaction().execute(
            prepared_query,
            {'$code': code},
            commit_tx=False
        )
        
        if not result_sets[0].rows:
            print("ValidateSubCode: code not found")
            return error_response('INVALID_CODE', 'The subscription code does not exist')
        
        row = result_sets[0].rows[0]
        
        # Check if code is already used
        status_val = _s(row.status)
        if status_val != 'unused':
            print(f"ValidateSubCode: code status={status_val}")
            if status_val == 'active':
                return error_response('CODE_ALREADY_USED', 'This subscription code has already been activated')
            elif status_val == 'expired':
                return error_response('CODE_EXPIRED', 'This subscription code has expired')
        
        # Calculate activation and end dates using server time
        server_time = datetime.utcnow()
        activated_date = server_time
        
        # Calculate end date based on subscription type and duration
        subscription_type = _s(row.subscription_type)
        duration = _s(row.duration)
        
        if subscription_type == 'trial':
            # Trial is always 14 days regardless of duration field
            end_date = activated_date + timedelta(days=14)
        elif duration == 'monthly':
            end_date = activated_date + timedelta(days=30)
        elif duration == 'yearly':
            end_date = activated_date + timedelta(days=365)
        else:
            return error_response('INVALID_DURATION', f'Invalid duration: {duration}')
        
        # Update the subscription code with activation details
        update_query = """
        DECLARE $code AS Utf8;
        DECLARE $activated_date AS Timestamp;
        DECLARE $end_date AS Timestamp;
        DECLARE $status AS Utf8;
        DECLARE $activated_by AS Utf8;
        UPDATE subscription_codes
        SET activated_date = $activated_date,
            end_date = $end_date,
            status = $status,
            activated_by = $activated_by
        WHERE code = $code;
        """
        
        prepared_update = session.prepare(update_query)
        session.transaction().execute(
            prepared_update,
            {
                '$code': code,
                '$activated_date': activated_date,
                '$end_date': end_date,
                '$status': 'active',
                '$activated_by': user_id
            },
            commit_tx=True
        )
        
        # Return the activated subscription
        response = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps({
                'success': True,
                'subscription': {
                    'code': code,
                    'subscription_type': subscription_type,
                    'duration': duration,
                    'user_telegram': _s(row.user_telegram) if row.user_telegram else None,
                    'amount': float(row.amount),
                    'created_date': _iso(row.created_date),
                    'activated_date': _iso(activated_date),
                    'end_date': _iso(end_date),
                    'status': 'active',
                    'activated_by': user_id
                }
            })
        }
        print("ValidateSubCode: success response ready")
        return response
    
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