import os
import json
import ydb
import jwt
import logging
from typing import Optional, Tuple
from datetime import datetime

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
        for k, v in headers.items():
            if k.lower() == 'authorization' and isinstance(v, str) and v.startswith('Bearer '):
                return v[7:]
        return None

    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        try:
            token = JWTAuth.extract_token_from_event(event)
            if not token:
                return None, 'Authorization header missing or invalid format'
            payload = JWTAuth.verify_jwt_token(token, 'access')
            uid = payload.get('user_id')
            if not uid:
                return None, 'Invalid token: user_id not found'
            return uid, None
        except Exception as e:
            logger.error(f"Auth error: {e}")
            return None, 'Authentication error'


def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}

        wallet_id = (event.get('pathParameters') or {}).get('id')
        if not wallet_id:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet ID is required'})}

        driver = ydb.Driver(ydb.DriverConfig(
            endpoint=os.environ.get('YDB_ENDPOINT'),
            database=os.environ.get('YDB_DATABASE'),
            credentials=ydb.iam.MetadataUrlCredentials()
        ))
        driver.wait(fail_fast=True)
        pool = ydb.SessionPool(driver)

        def delete_wallet(session):
            # Wrap the whole operation in a single transaction for atomicity
            tx = session.transaction(ydb.SerializableReadWrite())

            # Verify wallet exists and ownership
            vq = session.prepare(
                """
                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT id, status FROM wallets WHERE id = $wallet_id AND user_id = $user_id;
                """
            )
            rs = tx.execute(vq, {'$wallet_id': wallet_id, '$user_id': user_id})
            if not rs[0].rows:
                # Nothing to commit; rollback and return 404
                try:
                    tx.rollback()
                except Exception:
                    pass
                return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet not found'})}

            row = rs[0].rows[0]
            status = str(row['status'])

            # If not archived, archive first to preserve previous behavior but allow deletion in one call
            if status != 'archived':
                tx.execute(
                    session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $ts AS Timestamp;
                        UPDATE wallets SET status = 'archived', updated_at = $ts WHERE id = $wallet_id AND user_id = $user_id;
                        """
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id, '$ts': datetime.utcnow()}
                )

            # Do NOT delete installments or payments; they must remain in the system.

            # Delete wallet balance row if exists
            tx.execute(
                session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                    DELETE FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                    """
                ),
                {'$wallet_id': wallet_id, '$user_id': user_id}
            )

            # Delete installment_allocations (in case any remain)
            tx.execute(
                session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                    DELETE FROM installment_allocations WHERE wallet_id = $wallet_id AND user_id = $user_id;
                    """
                ),
                {'$wallet_id': wallet_id, '$user_id': user_id}
            )

            # Delete ledger transactions related to this wallet
            tx.execute(
                session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                    DELETE FROM ledger_transactions WHERE wallet_id = $wallet_id AND user_id = $user_id;
                    """
                ),
                {'$wallet_id': wallet_id, '$user_id': user_id}
            )

            # Finally, delete wallet
            tx.execute(
                session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                    DELETE FROM wallets WHERE id = $wallet_id AND user_id = $user_id;
                    """
                ),
                {'$wallet_id': wallet_id, '$user_id': user_id}
            )

            # Commit atomic deletion
            tx.commit()

            return {'statusCode': 204, 'headers': {'Content-Type': 'application/json'}, 'body': ''}

        try:
            result = pool.retry_operation_sync(delete_wallet)
        finally:
            driver.stop()

        return result
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})}
