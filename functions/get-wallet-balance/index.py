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
    """Convert YDB timestamp to ISO format"""
    if ts is None:
        return None

    try:
        # Handle YDB Timestamp type
        if hasattr(ts, 'ToDatetime'):
            # YDB Timestamp object
            dt = ts.ToDatetime()
            return dt.isoformat()
        elif isinstance(ts, datetime):
            return ts.isoformat()
        elif isinstance(ts, int):
            # Handle microseconds timestamp
            if ts > 1e12:  # Microseconds
                return datetime.fromtimestamp(ts / 1000000).isoformat()
            else:  # Seconds
                return datetime.fromtimestamp(ts).isoformat()
        else:
            # Try to convert to string and parse
            str_ts = str(ts)
            try:
                return datetime.fromisoformat(str_ts.replace('Z', '+00:00')).isoformat()
            except:
                return str_ts
    except Exception as e:
        logger.warning(f"Failed to convert timestamp {ts}: {e}")
        return str(ts)

def convert_int64(value):
    """Convert YDB Int64 to Python int"""
    if value is None:
        return 0
    try:
        # Handle YDB Int64 type
        if hasattr(value, '__int__'):
            return int(value)
        elif isinstance(value, (int, float)):
            return int(value)
        else:
            return int(str(value))
    except Exception as e:
        logger.warning(f"Failed to convert Int64 {value}: {e}")
        return 0

def convert_uint64(value):
    """Convert YDB Uint64 to Python int"""
    if value is None:
        return 0
    try:
        # Handle YDB Uint64 type
        if hasattr(value, '__int__'):
            return int(value)
        elif isinstance(value, (int, float)):
            return int(value)
        else:
            return int(str(value))
    except Exception as e:
        logger.warning(f"Failed to convert Uint64 {value}: {e}")
        return 0

def handler(event, context):
    """
    Yandex Cloud Function handler to get wallet balance
    """
    try:
        # Log request
        logger.info(f"Received get wallet balance request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")

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

            def get_wallet_balance(session):
                logger.info(f"GET-WALLET-BALANCE API - Getting balance for wallet {wallet_id}")

                # Query wallet balance
                query = f"""
                SELECT
                    wallet_id,
                    user_id,
                    balance_minor_units,
                    version,
                    updated_at
                FROM wallet_balances
                WHERE wallet_id = '{wallet_id}' AND user_id = '{user_id}';
                """

                result_sets = session.transaction().execute(query, commit_tx=True)

                if not result_sets[0].rows:
                    logger.warning(f"GET-WALLET-BALANCE API - No balance found for wallet {wallet_id}")
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet balance not found'})
                    }

                row = result_sets[0].rows[0]

                # Validate that we have all required fields
                required_fields = ['wallet_id', 'user_id', 'balance_minor_units', 'version', 'updated_at']
                for field in required_fields:
                    if field not in row or row[field] is None:
                        logger.error(f"GET-WALLET-BALANCE API - Missing or null field: {field}")
                        return {
                            'statusCode': 500,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': f'Invalid balance data: missing {field}'})
                        }

                # Convert YDB types to Python types
                balance_minor_units = convert_int64(row['balance_minor_units'])
                version = convert_uint64(row['version'])
                updated_at = convert_timestamp(row['updated_at'])

                # Ensure wallet_id and user_id are strings
                wallet_id_str = str(row['wallet_id']) if row['wallet_id'] is not None else ''
                user_id_str = str(row['user_id']) if row['user_id'] is not None else ''

                logger.info(f"GET-WALLET-BALANCE API - Found balance: {balance_minor_units} minor units, version: {version}")

                balance_data = {
                    'wallet_id': wallet_id_str,
                    'user_id': user_id_str,
                    'balance_minor_units': balance_minor_units,
                    'balance_rubles': float(balance_minor_units / 100.0),
                    'version': version,
                    'updated_at': updated_at
                }

                logger.info(f"GET-WALLET-BALANCE API - Returning balance data for wallet {wallet_id}")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(balance_data)
                }

            # Execute with session pool
            result = pool.retry_operation_sync(get_wallet_balance)

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
