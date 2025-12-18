import os
import json
import uuid
import ydb
import jwt
import logging
from datetime import datetime
from typing import Optional, Tuple

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
        for key, value in headers.items():
            if key.lower() == 'authorization':
                if isinstance(value, str) and value.startswith('Bearer '):
                    return value[7:]
        return None

    @staticmethod
    def authenticate_request(event: dict) -> Tuple[Optional[str], Optional[str]]:
        try:
            token = JWTAuth.extract_token_from_event(event)
            if not token:
                return None, 'Authorization header missing or invalid format'
            payload = JWTAuth.verify_jwt_token(token, 'access')
            user_id = payload.get('user_id')
            if not user_id:
                return None, 'Invalid token: user_id not found'
            return user_id, None
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

        # Parse body
        try:
            raw = event.get('body', '{}')
            try:
                import base64
                body = json.loads(base64.b64decode(raw).decode('utf-8'))
            except Exception:
                body = json.loads(raw)
        except Exception:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON in request body'})}

        # Validate input
        try:
            amount_minor_units = int(body.get('amount_minor_units'))
        except Exception:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'amount_minor_units must be integer'})}
        if amount_minor_units <= 0:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'amount_minor_units must be > 0'})}
        description = str(body.get('description') or 'Manual withdraw')[:500]

        driver = ydb.Driver(ydb.DriverConfig(
            endpoint=os.environ.get('YDB_ENDPOINT'),
            database=os.environ.get('YDB_DATABASE'),
            credentials=ydb.iam.MetadataUrlCredentials()
        ))
        driver.wait(fail_fast=True, timeout=5)
        pool = ydb.SessionPool(driver)

        def withdraw(session):
            # Verify wallet
            wq = session.prepare(
                """
                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT id, currency, status, require_nonnegative FROM wallets WHERE id = $wallet_id AND user_id = $user_id;
                """
            )
            wrs = session.transaction().execute(wq, {'$wallet_id': wallet_id, '$user_id': user_id}, commit_tx=True)
            if not wrs[0].rows:
                return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet not found'})}
            wrow = wrs[0].rows[0]
            if str(wrow['status']) != 'active':
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Cannot withdraw from archived wallet'})}

            # Balance
            bq = session.prepare(
                """
                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                """
            )
            brs = session.transaction().execute(bq, {'$wallet_id': wallet_id, '$user_id': user_id}, commit_tx=True)
            if not brs[0].rows:
                return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet balance not found'})}
            brow = brs[0].rows[0]
            current_balance = int(brow['balance_minor_units'] or 0)
            current_version = int(brow['version'] or 0)
            new_balance = current_balance - amount_minor_units
            require_nonnegative = bool(wrow['require_nonnegative']) if wrow['require_nonnegative'] is not None else True
            if require_nonnegative and new_balance < 0:
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Insufficient funds'})}

            # Insert debit transaction
            txn_id = str(uuid.uuid4())
            now = datetime.utcnow()
            tq = session.prepare(
                """
                DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                DECLARE $direction AS Utf8; DECLARE $amount AS Int64; DECLARE $currency AS Utf8;
                DECLARE $reference_type AS Utf8; DECLARE $reference_id AS Utf8?; DECLARE $desc AS Utf8; DECLARE $now AS Timestamp;
                INSERT INTO ledger_transactions (
                  id, wallet_id, user_id, direction, amount_minor_units, currency,
                  reference_type, reference_id, description, created_by, created_at
                ) VALUES (
                  $id, $wallet_id, $user_id, $direction, $amount, $currency,
                  CAST('adjustment' AS Utf8), $reference_id, $desc, $user_id, $now
                );
                """
            )
            session.transaction().execute(tq, {
                '$id': txn_id, '$wallet_id': wallet_id, '$user_id': user_id,
                '$direction': 'debit', '$amount': amount_minor_units, '$currency': wrow['currency'],
                '$reference_id': None, '$desc': description, '$now': now
            }, commit_tx=True)

            # Update balance with optimistic locking
            uq = session.prepare(
                """
                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $new_balance AS Int64;
                DECLARE $new_version AS Uint64; DECLARE $exp_ver AS Uint64; DECLARE $now AS Timestamp;
                UPDATE wallet_balances SET balance_minor_units = $new_balance, version = $new_version, updated_at = $now
                WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $exp_ver;
                """
            )
            session.transaction().execute(uq, {
                '$wallet_id': wallet_id, '$user_id': user_id, '$new_balance': new_balance,
                '$new_version': current_version + 1, '$exp_ver': current_version, '$now': now
            }, commit_tx=True)

            return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'transaction_id': txn_id, 'new_balance_minor_units': new_balance, 'amount_withdrawn_minor_units': amount_minor_units})}

        try:
            result = pool.retry_operation_sync(withdraw)
        finally:
            driver.stop()
        return result
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})}
