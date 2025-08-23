import os
import json
import ydb
import jwt
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

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

def convert_timestamp(ts):
    """Convert timestamp to ISO format"""
    if isinstance(ts, datetime):
        return ts.isoformat()
    elif isinstance(ts, int):
        return datetime.fromtimestamp(ts / 1000000).isoformat()  # YDB timestamp is in microseconds
    return ts

def handler(event, context):
    """
    Yandex Cloud Function handler to get wallet transaction ledger with pagination
    """
    try:
        # Log request
        logger.info(f"Received wallet ledger request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Extract wallet ID from path
        path_parameters = event.get('pathParameters') or {}
        wallet_id = path_parameters.get('id')
        
        if not wallet_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Wallet ID is required'})
            }
        
        # 3. Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        limit = min(int(query_params.get('limit', 50)), 100)  # Max 100 transactions per request
        reference_type = query_params.get('type')  # Optional filter by transaction type
        start_date = query_params.get('start_date')  # ISO format date
        end_date = query_params.get('end_date')  # ISO format date
        
        # 4. Database operations
        try:
            # Use metadata authentication
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            
            # Create session pool
            pool = ydb.SessionPool(driver)
            
            def get_wallet_ledger(session):
                # First, verify wallet exists and belongs to user
                wallet_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                
                SELECT id, name, currency, status
                FROM wallets 
                WHERE id = $wallet_id AND user_id = $user_id;
                """
                
                prepared_wallet = session.prepare(wallet_query)
                wallet_result = session.transaction().execute(
                    prepared_wallet,
                    {'$wallet_id': wallet_id, '$user_id': user_id},
                    commit_tx=True
                )
                
                if not wallet_result[0].rows:
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet not found'})
                    }
                
                wallet_row = wallet_result[0].rows[0]
                
                # Build transaction query with filters
                base_query = """
                SELECT 
                    id,
                    wallet_id,
                    user_id,
                    direction,
                    amount_minor_units,
                    currency,
                    reference_type,
                    reference_id,
                    group_id,
                    correlation_id,
                    description,
                    created_by,
                    created_at
                FROM ledger_transactions
                WHERE wallet_id = $wallet_id AND user_id = $user_id
                """
                
                params = {
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$limit': limit,
                }
                
                # Add filters
                if reference_type:
                    base_query += " AND reference_type = $reference_type"
                    params['$reference_type'] = reference_type
                
                if start_date:
                    try:
                        start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
                        base_query += " AND created_at >= $start_date"
                        params['$start_date'] = start_dt
                    except ValueError:
                        return {
                            'statusCode': 400,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'Invalid start_date format. Use ISO format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)'})
                        }
                
                if end_date:
                    try:
                        end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
                        base_query += " AND created_at <= $end_date"
                        params['$end_date'] = end_dt
                    except ValueError:
                        return {
                            'statusCode': 400,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'Invalid end_date format. Use ISO format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)'})
                        }
                
                # Order by created_at DESC for most recent first, limit results
                base_query += " ORDER BY created_at DESC LIMIT $limit;"
                
                prepared_query = session.prepare(base_query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    params,
                    commit_tx=True
                )
                
                transactions = []
                for row in result_sets[0].rows:
                    transaction_data = {
                        'id': row['id'],
                        'wallet_id': row['wallet_id'],
                        'user_id': row['user_id'],
                        'direction': row['direction'],
                        'amount_minor_units': row['amount_minor_units'],
                        'amount_rubles': row['amount_minor_units'] / 100.0,
                        'signed_amount_minor_units': row['amount_minor_units'] if row['direction'] == 'credit' else -row['amount_minor_units'],
                        'signed_amount_rubles': (row['amount_minor_units'] if row['direction'] == 'credit' else -row['amount_minor_units']) / 100.0,
                        'currency': row['currency'],
                        'reference_type': row['reference_type'],
                        'reference_id': row['reference_id'],
                        'group_id': row['group_id'],
                        'correlation_id': row['correlation_id'],
                        'description': row['description'],
                        'created_by': row['created_by'],
                        'created_at': convert_timestamp(row['created_at']),
                    }
                    transactions.append(transaction_data)
                
                # Calculate running balance (from most recent to oldest)
                running_balance = 0
                for i in range(len(transactions) - 1, -1, -1):  # Reverse order for calculation
                    running_balance += transactions[i]['signed_amount_minor_units']
                    transactions[i]['running_balance_minor_units'] = running_balance
                    transactions[i]['running_balance_rubles'] = running_balance / 100.0
                
                response_data = {
                    'wallet': {
                        'id': wallet_row['id'],
                        'name': wallet_row['name'],
                        'currency': wallet_row['currency'],
                        'status': wallet_row['status'],
                    },
                    'transactions': transactions,
                    'pagination': {
                        'limit': limit,
                        'count': len(transactions),
                        'has_more': len(transactions) == limit,  # Assume more if we hit the limit
                    },
                    'filters': {
                        'reference_type': reference_type,
                        'start_date': start_date,
                        'end_date': end_date,
                    }
                }
                
                logger.info(f"Retrieved {len(transactions)} transactions for wallet {wallet_id}")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(response_data)
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(get_wallet_ledger)
            
            # Clean up
            driver.stop()
            
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database operation failed'})
            }
        
        except Exception as e:
            logger.error(f"Database connection error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database connection failed'})
            }
            
    except Exception as e:
        # Generic error handler
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }