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

def convert_date(d):
    """Convert date to ISO format"""
    if d is None:
        return None
    if hasattr(d, 'isoformat'):
        return d.isoformat()
    return str(d)

def handler(event, context):
    """
    Yandex Cloud Function handler to list user's wallets with balances
    """
    try:
        # Log request
        logger.info(f"Received list wallets request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        wallet_type = query_params.get('type')  # Optional filter by type
        
        # 3. Database operations
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
            
            def list_wallets_with_balances(session):
                # Build query based on filters
                base_query = """
                SELECT 
                    w.id,
                    w.user_id,
                    w.name,
                    w.type,
                    w.currency,
                    w.status,
                    w.require_nonnegative,
                    w.allow_partial_allocation,
                    w.investment_amount_minor_units,
                    w.investor_percentage,
                    w.user_percentage,
                    w.investment_return_date,
                    w.created_at,
                    w.updated_at,
                    b.balance_minor_units,
                    b.version,
                    b.updated_at as balance_updated_at
                FROM wallets AS w
                LEFT JOIN wallet_balances AS b ON w.id = b.wallet_id AND w.user_id = b.user_id
                WHERE w.user_id = $user_id
                """
                
                params = {'$user_id': user_id}
                
                if wallet_type:
                    base_query += " AND w.type = $type"
                    params['$type'] = wallet_type
                
                base_query += " ORDER BY w.created_at DESC;"
                
                prepared_query = session.prepare(base_query)
                result_sets = session.transaction().execute(
                    prepared_query,
                    params,
                    commit_tx=True
                )
                
                wallets = []
                for row in result_sets[0].rows:
                    wallet_data = {
                        'id': row['id'],
                        'user_id': row['user_id'],
                        'name': row['name'],
                        'type': row['type'],
                        'currency': row['currency'],
                        'status': row['status'],
                        'require_nonnegative': row['require_nonnegative'],
                        'allow_partial_allocation': row['allow_partial_allocation'],
                        'investment_amount_minor_units': row['investment_amount_minor_units'],
                        'investor_percentage': float(row['investor_percentage']) if row['investor_percentage'] is not None else None,
                        'user_percentage': float(row['user_percentage']) if row['user_percentage'] is not None else None,
                        'investment_return_date': convert_date(row['investment_return_date']),
                        'created_at': convert_timestamp(row['created_at']),
                        'updated_at': convert_timestamp(row['updated_at']),
                        'balance': {
                            'balance_minor_units': row['balance_minor_units'] or 0,
                            'balance_rubles': (row['balance_minor_units'] or 0) / 100.0,
                            'version': row['version'] or 1,
                            'updated_at': convert_timestamp(row['balance_updated_at']) if row['balance_updated_at'] else None,
                        }
                    }
                    
                    # Add computed fields for investor wallets
                    if wallet_data['type'] == 'investor' and wallet_data['investment_amount_minor_units']:
                        investment_amount = wallet_data['investment_amount_minor_units']
                        current_balance = wallet_data['balance']['balance_minor_units']
                        
                        # For now, we'll calculate based on current balance only
                        # In a full implementation, this would include allocated funds
                        total_wallet_value = current_balance
                        total_profit = total_wallet_value - investment_amount
                        
                        if total_profit > 0 and wallet_data['investor_percentage']:
                            investor_profit_share = int(total_profit * wallet_data['investor_percentage'] / 100)
                            expected_returns = investment_amount + investor_profit_share
                        else:
                            investor_profit_share = 0
                            expected_returns = investment_amount
                        
                        wallet_data['investment_summary'] = {
                            'total_invested_minor_units': investment_amount,
                            'total_invested_rubles': investment_amount / 100.0,
                            'current_wallet_value_minor_units': total_wallet_value,
                            'current_wallet_value_rubles': total_wallet_value / 100.0,
                            'total_profit_minor_units': max(0, total_profit),
                            'total_profit_rubles': max(0, total_profit) / 100.0,
                            'investor_profit_share_minor_units': investor_profit_share,
                            'investor_profit_share_rubles': investor_profit_share / 100.0,
                            'expected_returns_minor_units': expected_returns,
                            'expected_returns_rubles': expected_returns / 100.0,
                            'roi_percentage': (investor_profit_share / investment_amount * 100) if investment_amount > 0 else 0.0,
                        }
                    
                    wallets.append(wallet_data)
                
                logger.info(f"Retrieved {len(wallets)} wallets for user {user_id}")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(wallets)
                }
            
            # Execute with session pool
            result = pool.retry_operation_sync(list_wallets_with_balances)
            
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