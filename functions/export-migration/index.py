import json
import logging
import os
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional, Tuple

import jwt
import ydb

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DEFAULT_CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,X-API-Key,Authorization',
}


def _cors(resp):
    headers = resp.get('headers', {})
    return {**resp, 'headers': {**DEFAULT_CORS_HEADERS, **headers}}


class JWTAuth:
    @staticmethod
    def verify_jwt_token(token: str, token_type: str = 'access') -> dict:
        secret_key = os.environ.get('JWT_SECRET_KEY', 'your-super-secret-jwt-key-change-in-production')
        try:
            payload = jwt.decode(token, secret_key, algorithms=['HS256'])
            if payload.get('type') != token_type:
                raise ValueError(f'Invalid token type. Expected {token_type}')
            return payload
        except jwt.ExpiredSignatureError:
            raise ValueError('Token has expired')
        except jwt.InvalidTokenError:
            raise ValueError('Invalid token')

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
                return None, 'Authorization header missing or invalid format'

            payload = JWTAuth.verify_jwt_token(token, 'access')
            user_id = payload.get('user_id')
            if not user_id:
                return None, 'Invalid token: user_id not found'

            logger.info('Export request authenticated for user=%s', user_id)
            return user_id, None
        except ValueError as e:
            return None, f'Authentication failed: {str(e)}'
        except Exception:
            logger.exception('Unexpected authentication error')
            return None, 'Authentication error'


def _to_iso_timestamp(value) -> str:
    if value is None:
        return ''
    if isinstance(value, int):
        # YDB Timestamp may come as microseconds from Unix epoch.
        return datetime.utcfromtimestamp(value / 1_000_000).isoformat() + 'Z'
    if isinstance(value, datetime):
        return value.isoformat()
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return str(value)


def _to_iso_date(value) -> str:
    if value is None:
        return ''
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, int):
        # YDB Date may come as days since Unix epoch.
        epoch_ordinal = date(1970, 1, 1).toordinal()
        return date.fromordinal(value + epoch_ordinal).isoformat()
    return str(value)


def _to_cents(value) -> int:
    if value is None or value == '':
        return 0
    decimal_value = value if isinstance(value, Decimal) else Decimal(str(value))
    return int((decimal_value * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))


def _read_rows(session, query: str, params: dict):
    prepared = session.prepare(query)
    result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
        prepared,
        params,
        commit_tx=True,
    )
    if not result_sets:
        return []
    return list(result_sets[0].rows)


def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    if event.get('httpMethod') != 'GET':
        return _cors({
            'statusCode': 405,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Method not allowed'}),
        })

    user_id, auth_error = JWTAuth.authenticate_request(event)
    if not user_id:
        return _cors({
            'statusCode': 401,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Unauthorized: {auth_error}'}),
        })

    driver = None
    try:
        driver_config = ydb.DriverConfig(
            endpoint=os.environ.get('YDB_ENDPOINT'),
            database=os.environ.get('YDB_DATABASE'),
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True, timeout=5)
        pool = ydb.SessionPool(driver)

        def export_data(session):
            clients_query = """
            DECLARE $user_id AS Utf8;
            SELECT id, full_name, contact_number, passport_number, address, created_at, updated_at
            FROM clients
            WHERE user_id = $user_id
            ORDER BY created_at ASC;
            """
            client_rows = _read_rows(session, clients_query, {'$user_id': user_id})

            installments_query = """
            DECLARE $user_id AS Utf8;
            SELECT
                id,
                client_id,
                installment_number,
                product_name,
                cash_price,
                installment_price,
                term_months,
                down_payment,
                monthly_payment,
                down_payment_date,
                installment_start_date,
                created_at,
                updated_at
            FROM installments
            WHERE user_id = $user_id
            ORDER BY created_at ASC;
            """
            installment_rows = _read_rows(session, installments_query, {'$user_id': user_id})

            payments_query = """
            DECLARE $user_id AS Utf8;
            SELECT
                p.id AS id,
                p.installment_id AS installment_id,
                p.payment_number AS payment_number,
                p.due_date AS due_date,
                p.expected_amount AS expected_amount,
                COALESCE(p.paid_amount, CAST(0 AS Decimal(22,9))) AS paid_amount,
                p.is_paid AS is_paid,
                p.paid_date AS paid_date,
                p.created_at AS created_at,
                p.updated_at AS updated_at
            FROM installment_payments AS p
            INNER JOIN installments AS i ON i.id = p.installment_id
            WHERE i.user_id = $user_id
            ORDER BY p.installment_id ASC, p.payment_number ASC, p.created_at ASC;
            """
            payment_rows = _read_rows(session, payments_query, {'$user_id': user_id})

            clients = []
            for row in client_rows:
                clients.append({
                    'legacy_id': str(row.id),
                    'full_name': str(row.full_name or ''),
                    'contact_number': str(row.contact_number or ''),
                    'passport_number': str(row.passport_number or ''),
                    'address': str(row.address or ''),
                    'status': 'active',
                    'created_at': _to_iso_timestamp(row.created_at),
                    'updated_at': _to_iso_timestamp(row.updated_at),
                })

            installments = []
            for row in installment_rows:
                installments.append({
                    'legacy_id': str(row.id),
                    'legacy_client_id': str(row.client_id),
                    'installment_number': int(getattr(row, 'installment_number', 0) or 0),
                    'product_name': str(row.product_name or ''),
                    'cash_price_cents': _to_cents(row.cash_price),
                    'installment_price_cents': _to_cents(row.installment_price),
                    'term_months': int(row.term_months or 0),
                    'down_payment_cents': _to_cents(row.down_payment),
                    'monthly_payment_cents': _to_cents(row.monthly_payment),
                    'down_payment_date': _to_iso_date(row.down_payment_date),
                    'installment_start_date': _to_iso_date(row.installment_start_date),
                    'status': 'active',
                    'created_at': _to_iso_timestamp(row.created_at),
                    'updated_at': _to_iso_timestamp(row.updated_at),
                })

            payments = []
            for row in payment_rows:
                payments.append({
                    'legacy_id': str(row.id),
                    'legacy_installment_id': str(row.installment_id),
                    'payment_number': int(row.payment_number or 0),
                    'due_date': _to_iso_date(row.due_date),
                    'expected_amount_cents': _to_cents(row.expected_amount),
                    'is_paid': bool(row.is_paid),
                    'paid_amount_cents': _to_cents(row.paid_amount),
                    'paid_date': _to_iso_date(row.paid_date),
                    'payment_method': '',
                    'transaction_ref': '',
                    'created_at': _to_iso_timestamp(row.created_at),
                    'updated_at': _to_iso_timestamp(row.updated_at),
                })

            payload = {
                'clients': clients,
                'installments': installments,
                'payments': payments,
            }

            return _cors({
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(payload, ensure_ascii=False),
            })

        return pool.retry_operation_sync(export_data)

    except ydb.Error as e:
        logger.exception('YDB error while exporting migration payload')
        return _cors({
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Database operation failed: {str(e)}'}),
        })
    except Exception:
        logger.exception('Unexpected error while exporting migration payload')
        return _cors({
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'}),
        })
    finally:
        if driver is not None:
            driver.stop()
