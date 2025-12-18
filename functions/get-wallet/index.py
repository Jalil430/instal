import os
import json
import ydb
import jwt
import logging
import time
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DEFAULT_CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,X-API-Key,Authorization'
}

def _cors(resp):
    headers = resp.get('headers', {})
    return {**resp, 'headers': {**DEFAULT_CORS_HEADERS, **headers}}


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
    """Convert date to ISO format - handles various YDB date formats"""
    if d is None:
        return None

    print(f"🔄 Converting date: {d}, type: {type(d)}")

    try:
        # Handle different date object types
        if hasattr(d, 'isoformat') and callable(getattr(d, 'isoformat')):
            result = d.isoformat()
            print(f"✅ Used isoformat(): {result}")
            return result

        # Handle datetime-like objects with date() method
        if hasattr(d, 'date') and callable(getattr(d, 'date')):
            result = d.date().isoformat()
            print(f"✅ Used date().isoformat(): {result}")
            return result

        # Handle string dates
        if isinstance(d, str):
            try:
                from datetime import datetime
                # Handle various string formats
                clean_str = d.replace('Z', '+00:00').replace('z', '+00:00')
                if 'T' in clean_str:
                    parsed_date = datetime.fromisoformat(clean_str)
                    result = parsed_date.date().isoformat()
                else:
                    parsed_date = datetime.fromisoformat(clean_str)
                    result = parsed_date.date().isoformat()
                print(f"✅ Parsed string date: {result}")
                return result
            except Exception as e:
                print(f"❌ String date parsing failed: {e}")
                return None

        # Handle numeric timestamps or YDB Date (days since epoch)
        if isinstance(d, (int, float)):
            from datetime import datetime, date, timedelta
            try:
                if d > 1e10:  # Microseconds (YDB Timestamp)
                    result = datetime.fromtimestamp(d / 1000000).date().isoformat()
                elif d > 1e9:  # Seconds (Unix timestamp)
                    result = datetime.fromtimestamp(d).date().isoformat()
                else:
                    # Treat as YDB Date: days since 1970-01-01
                    base = date(1970, 1, 1)
                    result = (base + timedelta(days=int(d))).isoformat()
                print(f"✅ Converted numeric timestamp: {result}")
                return result
            except Exception as e:
                print(f"❌ Numeric timestamp conversion failed: {e}")
                return None

        # Handle YDB date objects that might have different attributes
        if hasattr(d, 'year') and hasattr(d, 'month') and hasattr(d, 'day'):
            try:
                result = f"{d.year:04d}-{d.month:02d}-{d.day:02d}"
                print(f"✅ Constructed date from attributes: {result}")
                return result
            except Exception as e:
                print(f"❌ Date attribute construction failed: {e}")

        # Last resort: try to convert to string and see if it looks like a date
        str_val = str(d).strip()
        if len(str_val) >= 10 and '-' in str_val:
            # Looks like it might be a date string
            try:
                from datetime import datetime
                parsed_date = datetime.fromisoformat(str_val.replace('Z', '+00:00'))
                result = parsed_date.date().isoformat()
                print(f"✅ Parsed string fallback: {result}")
                return result
            except:
                pass

        print(f"⚠️ Could not convert date: {d} (type: {type(d)})")
        return None

    except Exception as e:
        print(f"💥 Date conversion error: {e}, value: {d}, type: {type(d)}")
        return None

def handler(event, context):
    """
    Yandex Cloud Function handler to get a single wallet with its balance
    """
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        # Log request
        logger.info(f"Received get wallet request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")

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

        logger.info(f"Requested wallet ID: {wallet_id}")

        if not wallet_id:
            logger.warning("Wallet ID is missing from path parameters")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Wallet ID is required'})
            }

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

            def get_wallet_with_balance(session):
                logger.info(f"GET-WALLET API - Querying wallet {wallet_id} for user {user_id}")

                # Small retry helper for transient throttling
                def _tx_exec_with_retry(prepared, params, *, max_attempts=5):
                    backoff = 0.15
                    for attempt in range(max_attempts):
                        try:
                            return session.transaction().execute(prepared, params, commit_tx=True)
                        except Exception as e:
                            msg = str(e)
                            if 'ResourceExhausted' in msg or 'RESOURCE_EXHAUSTED' in msg:
                                time.sleep(backoff)
                                backoff = min(backoff * 2, 1.0)
                                continue
                            raise

                # Fetch wallet without JOIN (matches list-wallets behavior)
                wallet_query = session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8;
                    DECLARE $user_id AS Utf8;
                    SELECT
                        id AS id,
                        user_id AS user_id,
                        name AS name,
                        type AS type,
                        currency AS currency,
                        status AS status,
                        require_nonnegative AS require_nonnegative,
                        allow_partial_allocation AS allow_partial_allocation,
                        investment_amount_minor_units AS investment_amount_minor_units,
                        starting_amount_minor_units AS starting_amount_minor_units,
                        investor_percentage AS investor_percentage,
                        user_percentage AS user_percentage,
                        investment_return_date AS investment_return_date,
                        created_at AS created_at,
                        updated_at AS updated_at
                    FROM wallets
                    WHERE id = $wallet_id AND user_id = $user_id;
                    """
                )

                w_rs = _tx_exec_with_retry(
                    wallet_query,
                    {'$wallet_id': wallet_id, '$user_id': user_id}
                )

                if not w_rs[0].rows:
                    logger.warning(f"GET-WALLET API - Wallet {wallet_id} not found for user {user_id}")
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet not found'})
                    }

                row = w_rs[0].rows[0]
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
                logger.info("GET-WALLET API - Row fetched")

                # Check all fields for debugging
                logger.info(f"GET-WALLET API - Available fields: {list(row.keys())}")
                for field in ['type', 'investment_amount_minor_units', 'investor_percentage', 'user_percentage', 'investment_return_date']:
                    value = row.get(field)
                    logger.info(f"GET-WALLET API - {field}: {value} (type: {type(value)})")

                # Debug the investment_return_date field
                return_date = row.get('investment_return_date')
                logger.info(f"Raw investment_return_date: {return_date}, type: {type(return_date)}")

                # Debug row type and available methods
                logger.info(f"Row object type: {type(row)}")
                logger.info(f"Row object methods: {[method for method in dir(row) if not method.startswith('_')]}")

                # Convert dates with error handling
                try:
                    investment_return_date = convert_date(_val('investment_return_date'))
                    created_at = convert_timestamp(_val('created_at'))
                    updated_at = convert_timestamp(_val('updated_at'))
                    bal_upd = _val('balance_updated_at')
                    balance_updated_at = convert_timestamp(bal_upd) if bal_upd else None
                except Exception as e:
                    logger.error(f"Failed to convert timestamps: {e}")
                    investment_return_date = None
                    created_at = datetime.utcnow().isoformat()
                    updated_at = datetime.utcnow().isoformat()
                    balance_updated_at = None

                # Fetch balance using separate query to avoid JOIN issues
                balance_minor_units = 0
                balance_version = 1
                try:
                    bal_query = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8;
                        DECLARE $user_id AS Utf8;
                        SELECT balance_minor_units, version, updated_at,
                               total_allocated_minor_units, due_to_get_minor_units, expected_revenue_minor_units, spent_on_products_minor_units
                        FROM wallet_balances
                        WHERE wallet_id = $wallet_id AND user_id = $user_id;
                        """
                    )
                    b_rs = _tx_exec_with_retry(
                        bal_query,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    if b_rs[0].rows:
                        b_row = b_rs[0].rows[0]
                        balance_minor_units = int(b_row['balance_minor_units'] or 0)
                        balance_version = int(b_row['version'] or 1)
                        balance_updated_at = convert_timestamp(b_row['updated_at'])
                        # optional aggregates
                        try:
                            total_allocated_mu = int(b_row['total_allocated_minor_units'] or 0)
                            due_to_get_mu = int(b_row['due_to_get_minor_units'] or 0)
                            expected_revenue_mu = int(b_row['expected_revenue_minor_units'] or 0)
                            spent_on_products_mu = int(b_row.get('spent_on_products_minor_units') or 0)
                        except Exception:
                            total_allocated_mu = 0
                            due_to_get_mu = 0
                            expected_revenue_mu = 0
                            spent_on_products_mu = 0
                    else:
                        balance_updated_at = None
                except Exception as e:
                    logger.error(f"GET-WALLET API - Balance fetch error: {e}")
                    balance_updated_at = None

                # Use the same logic as list-wallets API
                raw_type = _str(_val('type'))
                logger.info(f"GET-WALLET API - Raw type: {raw_type}")

                # Check if this wallet has investment fields to determine if it should be investor
                has_investment_fields = (
                    _val('investment_amount_minor_units') is not None or
                    _val('investor_percentage') is not None or
                    _val('user_percentage') is not None or
                    _val('investment_return_date') is not None
                )

                # Check if this wallet has personal wallet starting amount
                has_personal_fields = (_val('starting_amount_minor_units') is not None)

                logger.info(f"GET-WALLET API - Has investment fields: {has_investment_fields}")
                logger.info(f"GET-WALLET API - Has personal fields: {has_personal_fields}")

                # Determine wallet type (prefer investor fields to match UI expectations)
                db_type = (str(raw_type).strip().lower() if raw_type else '')
                if has_investment_fields:
                    final_type = 'investor'
                    logger.info(f"GET-WALLET API - Inferred investor by fields")
                elif db_type in ['investor', 'personal']:
                    final_type = db_type
                    logger.info(f"GET-WALLET API - Using DB type: {final_type}")
                elif has_personal_fields:
                    final_type = 'personal'
                    logger.info(f"GET-WALLET API - Inferred personal by fields")
                else:
                    final_type = 'personal'
                    logger.info(f"GET-WALLET API - Defaulted to personal")

                # balance fetched via separate query
                wallet_data = {
                    'id': _str(_val('id')) or '',
                    'user_id': _str(_val('user_id')) or '',
                    'name': _str(_val('name')) or '',
                    'type': final_type,
                    'currency': _str(_val('currency')) or 'RUB',
                    'status': _str(_val('status')) or 'active',
                    'require_nonnegative': bool(_val('require_nonnegative')) if _val('require_nonnegative') is not None else True,
                    'allow_partial_allocation': bool(_val('allow_partial_allocation')) if _val('allow_partial_allocation') is not None else False,
                    'investment_amount_minor_units': _val('investment_amount_minor_units'),
                    'starting_amount_minor_units': _val('starting_amount_minor_units'),
                    'investor_percentage': float(_val('investor_percentage')) if _val('investor_percentage') is not None else None,
                    'user_percentage': float(_val('user_percentage')) if _val('user_percentage') is not None else None,
                    'investment_return_date': investment_return_date,
                    'created_at': created_at,
                    'updated_at': updated_at,
                    'balance': {
                        'balance_minor_units': int(balance_minor_units or 0),
                        'balance_rubles': float((balance_minor_units or 0) / 100.0),
                        'version': int(balance_version or 1),
                        'updated_at': balance_updated_at,
                        'total_allocated_minor_units': int(locals().get('total_allocated_mu', 0)),
                        'due_to_get_minor_units': int(locals().get('due_to_get_mu', 0)),
                        'expected_revenue_minor_units': int(locals().get('expected_revenue_mu', 0)),
                        'spent_on_products_minor_units': int(locals().get('spent_on_products_mu', 0)),
                    }
                }

                if wallet_data['type'] not in ['personal', 'investor']:
                    wallet_data['type'] = 'investor' if has_investment_fields else 'personal'
                logger.info(f"GET-WALLET API - Final wallet type in response: {wallet_data['type']}")

                # Add investment summary for investor wallets (normalized to app model)
                if wallet_data['type'] == 'investor' and wallet_data['investment_amount_minor_units']:
                    investment_amount = int(wallet_data['investment_amount_minor_units'] or 0)
                    current_balance = int(wallet_data['balance']['balance_minor_units'] or 0)

                    # Sum of active allocations from this wallet
                    allocations_sum_query = f"""
                    SELECT COALESCE(SUM(amount_minor_units), 0) AS total_allocated
                    FROM installment_allocations
                    WHERE wallet_id = '{_str(_val('id'))}' AND user_id = '{user_id}' AND status = 'active';
                    """
                    alloc_rs = session.transaction().execute(allocations_sum_query, commit_tx=True)
                    total_allocated = int(alloc_rs[0].rows[0]['total_allocated']) if alloc_rs and alloc_rs[0].rows else 0

                    profit_pct = float(wallet_data['investor_percentage'] or 0.0)
                    total_wallet_value = current_balance + total_allocated
                    total_profit = max(0, total_wallet_value - investment_amount)
                    investor_profit_share = int(total_profit * (profit_pct / 100.0)) if profit_pct > 0 else 0
                    expected_returns = investment_amount + investor_profit_share

                    wallet_data['investment_summary'] = {
                        'wallet_id': str(_str(_val('id')) or ''),
                        'total_invested_minor_units': investment_amount,
                        'current_balance_minor_units': current_balance,
                        'total_allocated_minor_units': total_allocated,
                        'expected_returns_minor_units': expected_returns,
                        'due_amount_minor_units': total_allocated,
                        'return_due_date': investment_return_date,
                        'profit_percentage': profit_pct,
                    }

                logger.info(f"Successfully retrieved wallet {wallet_id}, returning data")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(wallet_data)
                }

            # Execute with session pool
            result = pool.retry_operation_sync(get_wallet_with_balance)

            # Clean up
            driver.stop()

            return result

        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            logger.error(f"Error details: {e.__class__.__name__}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Database operation failed: {str(e)}'})
            }

        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            logger.error(f"Error type: {e.__class__.__name__}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Internal server error: {str(e)}'})
            }

    except Exception as e:
        # Generic error handler
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
