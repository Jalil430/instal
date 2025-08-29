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


class JWTAuth:
    """Handles JWT token authentication and validation"""

    @staticmethod
    def verify_jwt_token(token: str, token_type: str = 'access') -> dict:
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        if payload.get('type') != token_type:
            raise ValueError(f"Invalid token type. Expected {token_type}")
        return payload

    @staticmethod
    def extract_token_from_event(event: dict) -> Optional[str]:
        headers = event.get('headers', {})
        auth_header = None
        for key, value in headers.items():
            if key.lower() == 'authorization':
                auth_header = value
                break
        if not auth_header or not auth_header.startswith('Bearer '):
            return None
        return auth_header[7:]

    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        try:
            token = JWTAuth.extract_token_from_event(event)
            if not token:
                return None, "Authorization header missing or invalid format"
            payload = JWTAuth.verify_jwt_token(token, 'access')
            user_id = payload.get('user_id')
            if not user_id:
                return None, "Invalid token: user_id not found"
            return user_id, None
        except jwt.ExpiredSignatureError:
            return None, "Token has expired"
        except jwt.InvalidTokenError:
            return None, "Invalid token"
        except Exception as e:
            logger.error(f"Unexpected authentication error: {e}")
            return None, "Authentication error"


def convert_timestamp(ts):
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts.isoformat()
    if isinstance(ts, int):
        # YDB returns microseconds; fall back to seconds if small
        return datetime.fromtimestamp(ts / 1_000_000 if ts > 1e12 else ts).isoformat()
    try:
        return datetime.fromisoformat(str(ts).replace('Z', '+00:00')).isoformat()
    except Exception:
        return str(ts)


def handler(event, context):
    """List all wallet balances for the authenticated user"""
    try:
        logger.info(
            f"Received list wallet balances request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}"
        )

        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def list_balances(session):
                def _str(v):
                    if v is None:
                        return ''
                    try:
                        return v.decode('utf-8') if isinstance(v, (bytes, bytearray)) else str(v)
                    except Exception:
                        return str(v)
                query = f"""
                SELECT wallet_id, user_id, balance_minor_units, version, updated_at
                FROM wallet_balances
                WHERE user_id = '{user_id}'
                ORDER BY updated_at DESC
                """
                rs = session.transaction().execute(query, commit_tx=True)
                balances = []
                for row in rs[0].rows:
                    bal_minor = int((row['balance_minor_units'] or 0))
                    balances.append({
                        'wallet_id': _str(row['wallet_id']) or '',
                        'user_id': _str(row['user_id']) or '',
                        'balance_minor_units': bal_minor,
                        'balance_rubles': float(bal_minor / 100.0),
                        'version': int((row['version'] or 1)),
                        'updated_at': convert_timestamp(row['updated_at']),
                    })
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(balances)
                }

            result = pool.retry_operation_sync(list_balances)
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
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
