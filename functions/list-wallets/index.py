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
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts.isoformat()
    elif isinstance(ts, int):
        # Handle different timestamp formats
        if ts > 1e12:  # Microseconds (YDB format)
            return datetime.fromtimestamp(ts / 1000000).isoformat()
        elif ts > 1e9:  # Seconds (Unix timestamp)
            return datetime.fromtimestamp(ts).isoformat()
        else:
            # Very small timestamp, might be invalid - return a default date
            return datetime.now().isoformat()
    elif isinstance(ts, str):
        # Try to parse as ISO string
        try:
            return datetime.fromisoformat(ts.replace('Z', '+00:00')).isoformat()
        except:
            return None
    return str(ts)

def convert_date(d):
    """Convert date to ISO format"""
    if d is None:
        return None
    if hasattr(d, 'isoformat'):
        return d.isoformat()
    elif isinstance(d, str):
        # Try to parse as ISO string
        try:
            return datetime.fromisoformat(d.replace('Z', '+00:00')).date().isoformat()
        except:
            return None
    elif isinstance(d, int):
        # Handle numeric timestamps that might be invalid
        try:
            if d > 1e10:  # Likely microseconds timestamp
                return datetime.fromtimestamp(d / 1000000).date().isoformat()
            elif d > 1e9:  # Likely seconds timestamp
                return datetime.fromtimestamp(d).date().isoformat()
            else:
                # Invalid small number, return None
                return None
        except:
            return None
    return None

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
                # Build query based on filters and join balances
                base_query = f"""
                SELECT
                    w.id AS id,
                    w.user_id AS user_id,
                    w.name AS name,
                    w.type AS type,
                    w.currency AS currency,
                    w.status AS status,
                    w.require_nonnegative AS require_nonnegative,
                    w.allow_partial_allocation AS allow_partial_allocation,
                    w.investment_amount_minor_units AS investment_amount_minor_units,
                    w.starting_amount_minor_units AS starting_amount_minor_units,
                    w.investor_percentage AS investor_percentage,
                    w.user_percentage AS user_percentage,
                    w.investment_return_date AS investment_return_date,
                    w.created_at AS created_at,
                    w.updated_at AS updated_at,
                    wb.balance_minor_units AS balance_minor_units,
                    wb.version AS balance_version,
                    wb.updated_at AS balance_updated_at,
                    wb.total_allocated_minor_units AS total_allocated_minor_units,
                    wb.due_to_get_minor_units AS due_to_get_minor_units,
                    wb.expected_revenue_minor_units AS expected_revenue_minor_units
                FROM wallets w
                LEFT JOIN wallet_balances wb ON wb.wallet_id = w.id AND wb.user_id = w.user_id
                WHERE w.user_id = '{user_id}'
                """

                if wallet_type:
                    base_query += f" AND type = '{wallet_type}'"

                base_query += " ORDER BY created_at DESC;"

                result_sets = session.transaction().execute(
                    base_query,
                    commit_tx=True
                )

                wallets = []
                for row in result_sets[0].rows:
                    def _val(key):
                        try:
                            return row[key]
                        except Exception:
                            return None
                    def _str(v):
                        if v is None:
                            return None
                        try:
                            return v.decode('utf-8') if isinstance(v, (bytes, bytearray)) else str(v)
                        except Exception:
                            return str(v)
                    # DEBUG: Check if type field exists
                    raw_type = _str(_val('type'))
                    name_dbg = _str(_val('name')) or ''
                    logger.info(f"LIST-WALLETS API - Raw type field: {raw_type} for wallet {name_dbg}")

                    # Check if this wallet has investment fields to determine if it should be investor
                    has_investment_fields = (
                        _val('investment_amount_minor_units') is not None or
                        _val('investor_percentage') is not None or
                        _val('user_percentage') is not None or
                        _val('investment_return_date') is not None
                    )

                    # Check if this wallet has personal wallet starting amount
                    has_personal_fields = (_val('starting_amount_minor_units') is not None)

                    logger.info(f"LIST-WALLETS API - Has investment fields: {has_investment_fields} for wallet {name_dbg}")
                    logger.info(f"LIST-WALLETS API - Has personal fields: {has_personal_fields} for wallet {name_dbg}")

                    # Determine wallet type (prefer DB value when valid)
                    db_type = (str(raw_type).strip().lower() if raw_type else '')
                    if db_type in ['investor', 'personal']:
                        final_type = db_type
                        logger.info(f"LIST-WALLETS API - Using DB type: {final_type} for {name_dbg}")
                    elif has_investment_fields:
                        final_type = 'investor'
                        logger.info(f"LIST-WALLETS API - Inferred investor by fields for {name_dbg}")
                    elif has_personal_fields:
                        final_type = 'personal'
                        logger.info(f"LIST-WALLETS API - Inferred personal by fields for {name_dbg}")
                    else:
                        final_type = 'personal'
                        logger.info(f"LIST-WALLETS API - Defaulted to personal for {name_dbg}")

                    balance_minor_units = int(_val('balance_minor_units') or 0)
                    balance_version = _val('balance_version') or 1
                    balance_updated_at = convert_timestamp(_val('balance_updated_at')) if _val('balance_updated_at') is not None else None

                    wallet_data = {
                        'id': _str(_val('id')) or '',
                        'user_id': _str(_val('user_id')) or '',
                        'name': _str(_val('name')) or '',
                        'type': final_type,
                        'currency': _str(_val('currency')) or 'RUB',
                        'status': _str(_val('status')) or 'active',
                        'require_nonnegative': _val('require_nonnegative'),
                        'allow_partial_allocation': _val('allow_partial_allocation'),
                        'investment_amount_minor_units': _val('investment_amount_minor_units'),
                        'starting_amount_minor_units': _val('starting_amount_minor_units'),
                        'investor_percentage': float(_val('investor_percentage')) if _val('investor_percentage') is not None else None,
                        'user_percentage': float(_val('user_percentage')) if _val('user_percentage') is not None else None,
                        'investment_return_date': convert_date(_val('investment_return_date')),
                        'created_at': convert_timestamp(_val('created_at')),
                        'updated_at': convert_timestamp(_val('updated_at')),
                        'balance': {
                            'balance_minor_units': int(balance_minor_units or 0),
                            'balance_rubles': float((balance_minor_units or 0) / 100.0),
                            'version': int(balance_version or 1),
                            'updated_at': balance_updated_at,
                            'total_allocated_minor_units': int(_val('total_allocated_minor_units') or 0),
                            'due_to_get_minor_units': int(_val('due_to_get_minor_units') or 0),
                            'expected_revenue_minor_units': int(_val('expected_revenue_minor_units') or 0),
                        }
                    }

                    # Normalize unexpected types
                    if wallet_data['type'] not in ['personal', 'investor']:
                        wallet_data['type'] = 'investor' if has_investment_fields else 'personal'
                    logger.info(f"LIST-WALLETS API - Final type for {name_dbg}: {wallet_data['type']}")
                    
                    # Add computed fields for investor wallets (normalized to app model)
                    if wallet_data['type'] == 'investor' and wallet_data['investment_amount_minor_units']:
                        investment_amount = int(wallet_data['investment_amount_minor_units'] or 0)
                        current_balance = int(wallet_data['balance']['balance_minor_units'] or 0)

                        # Sum of active allocations from this wallet
                        try:
                            allocations_sum_query = f"""
                            SELECT COALESCE(SUM(amount_minor_units), 0) AS total_allocated
                            FROM installment_allocations
                            WHERE wallet_id = '{_val('id')}' AND user_id = '{user_id}' AND status = 'active';
                            """
                            alloc_rs = session.transaction().execute(allocations_sum_query, commit_tx=True)
                            total_allocated = int(alloc_rs[0].rows[0]['total_allocated']) if alloc_rs and alloc_rs[0].rows else 0
                        except Exception as e:
                            logger.error(f"LIST-WALLETS API - Allocation sum failed for wallet {_val('id')}: {e}")
                            total_allocated = 0

                        profit_pct = float(wallet_data['investor_percentage'] or 0.0)
                        total_wallet_value = current_balance + total_allocated
                        total_profit = max(0, total_wallet_value - investment_amount)
                        investor_profit_share = int(total_profit * (profit_pct / 100.0)) if profit_pct > 0 else 0
                        expected_returns = investment_amount + investor_profit_share

                        wallet_data['investment_summary'] = {
                            'wallet_id': str(_val('id')),
                            'total_invested_minor_units': investment_amount,
                            'current_balance_minor_units': current_balance,
                            'total_allocated_minor_units': total_allocated,
                            'expected_returns_minor_units': expected_returns,
                            'due_amount_minor_units': total_allocated,
                            'return_due_date': convert_date(_val('investment_return_date')),
                            'profit_percentage': profit_pct,
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
