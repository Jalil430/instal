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

def handler(event, context):
    """
    Yandex Cloud Function handler to archive a wallet (soft delete)
    """
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        # Log request
        logger.info(f"Received wallet archive request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")

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

            def archive_wallet(session):
                # First, verify wallet exists and belongs to user
                verify_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;

                SELECT id, name, status, type
                FROM wallets
                WHERE id = $wallet_id AND user_id = $user_id;
                """

                prepared_verify = session.prepare(verify_query)
                verify_result = session.transaction().execute(
                    prepared_verify,
                    {'$wallet_id': wallet_id, '$user_id': user_id},
                    commit_tx=True
                )

                if not verify_result[0].rows:
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet not found'})
                    }

                wallet_row = verify_result[0].rows[0]
                current_status = wallet_row['status']

                if current_status == 'archived':
                    return {
                        'statusCode': 400,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Wallet is already archived'})
                    }

                # Archive wallet
                current_time = datetime.utcnow()

                archive_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $updated_at AS Timestamp;

                UPDATE wallets
                SET status = 'archived', updated_at = $updated_at
                WHERE id = $wallet_id AND user_id = $user_id;
                """

                prepared_archive = session.prepare(archive_query)
                session.transaction().execute(prepared_archive, {
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$updated_at': current_time,
                }, commit_tx=True)

                logger.info(f"Wallet {wallet_id} archived successfully")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'message': 'Wallet archived successfully',
                        'wallet_id': wallet_id
                    })
                }

            # Execute with session pool
            result = pool.retry_operation_sync(archive_wallet)

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
