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


def _to_minor_units(value) -> Optional[int]:
    if value is None or value == '':
        return None
    decimal_value = value if isinstance(value, Decimal) else Decimal(str(value))
    return int(decimal_value.quantize(Decimal('1'), rounding=ROUND_HALF_UP))


def _to_bps(value) -> Optional[int]:
    if value is None or value == '':
        return None
    decimal_value = value if isinstance(value, Decimal) else Decimal(str(value))
    return int((decimal_value * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))


def _to_text(value, default: str = '') -> str:
    if value is None:
        return default
    return str(value)


def _normalize_wallet_type(row) -> str:
    raw_type = _to_text(getattr(row, 'type', None)).strip().lower()
    if raw_type in ('investor', 'personal'):
        return raw_type

    if (
        getattr(row, 'investment_amount_minor_units', None) is not None
        or getattr(row, 'investor_percentage', None) is not None
        or getattr(row, 'user_percentage', None) is not None
        or getattr(row, 'investment_return_date', None) is not None
    ):
        return 'investor'

    if getattr(row, 'starting_amount_minor_units', None) is not None:
        return 'personal'

    return 'personal'


def _append_warning(warnings, seen_warnings, message: str):
    if message in seen_warnings:
        return
    warnings.append(message)
    seen_warnings.add(message)


def _resolve_profit_split(wallet_id: str, wallet_name: str, investor_percentage, user_percentage, warnings, seen_warnings):
    investor_bps = _to_bps(investor_percentage)
    company_bps = _to_bps(user_percentage)

    if investor_bps is None and company_bps is None:
        _append_warning(
            warnings,
            seen_warnings,
            f'Wallet "{wallet_name}" ({wallet_id}) has no profit split; exported with default 50/50 split.',
        )
        return 5000, 5000

    if investor_bps is None:
        investor_bps = 10000 - company_bps
    if company_bps is None:
        company_bps = 10000 - investor_bps

    if investor_bps < 0 or company_bps < 0 or investor_bps + company_bps != 10000:
        fallback_company_bps = 10000 - max(0, min(investor_bps, 10000))
        fallback_investor_bps = 10000 - fallback_company_bps
        if 0 <= investor_bps <= 10000:
            investor_bps = fallback_investor_bps
            company_bps = fallback_company_bps
        elif 0 <= company_bps <= 10000:
            company_bps = max(0, min(company_bps, 10000))
            investor_bps = 10000 - company_bps
        else:
            investor_bps, company_bps = 5000, 5000
        _append_warning(
            warnings,
            seen_warnings,
            f'Wallet "{wallet_name}" ({wallet_id}) had an invalid profit split; exporter normalized it to {investor_bps}/{company_bps} bps.',
        )

    return investor_bps, company_bps


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
            warnings = []
            seen_warnings = set()

            clients_query = """
            DECLARE $user_id AS Utf8;
            SELECT id, full_name, contact_number, passport_number, address, created_at, updated_at
            FROM clients
            WHERE user_id = $user_id
            ORDER BY created_at ASC;
            """
            client_rows = _read_rows(session, clients_query, {'$user_id': user_id})

            wallets_query = """
            DECLARE $user_id AS Utf8;
            SELECT
                w.id AS id,
                w.name AS name,
                w.type AS type,
                w.currency AS currency,
                w.status AS status,
                w.investment_amount_minor_units AS investment_amount_minor_units,
                w.starting_amount_minor_units AS starting_amount_minor_units,
                w.investor_percentage AS investor_percentage,
                w.user_percentage AS user_percentage,
                w.investment_return_date AS investment_return_date,
                w.created_at AS created_at,
                w.updated_at AS updated_at,
                wb.balance_minor_units AS balance_minor_units,
                wb.total_allocated_minor_units AS total_allocated_minor_units,
                wb.due_to_get_minor_units AS due_to_get_minor_units,
                wb.expected_revenue_minor_units AS expected_revenue_minor_units,
                wb.spent_on_products_minor_units AS spent_on_products_minor_units
            FROM wallets AS w
            LEFT JOIN wallet_balances AS wb ON wb.wallet_id = w.id AND wb.user_id = w.user_id
            WHERE w.user_id = $user_id
            ORDER BY w.created_at ASC, w.id ASC;
            """
            wallet_rows = _read_rows(session, wallets_query, {'$user_id': user_id})

            installments_query = """
            DECLARE $user_id AS Utf8;
            SELECT
                id,
                client_id,
                wallet_id,
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

            investors = []
            accounts = []
            exported_account_ids = set()

            for row in wallet_rows:
                wallet_id = _to_text(getattr(row, 'id', None)).strip()
                if not wallet_id:
                    continue

                wallet_name = _to_text(getattr(row, 'name', None)).strip() or f'Legacy wallet {wallet_id}'
                wallet_status = _to_text(getattr(row, 'status', None), 'active').strip() or 'active'
                wallet_currency = _to_text(getattr(row, 'currency', None), 'RUB').strip() or 'RUB'
                wallet_type = _normalize_wallet_type(row)
                created_at = _to_iso_timestamp(getattr(row, 'created_at', None))
                updated_at = _to_iso_timestamp(getattr(row, 'updated_at', None))

                account = {
                    'legacy_id': wallet_id,
                    'name': wallet_name,
                    'type': 'investor_account' if wallet_type == 'investor' else 'company_account',
                    'status': wallet_status,
                    'currency': wallet_currency,
                    'created_at': created_at,
                    'updated_at': updated_at,
                }

                initial_investment_minor_units = (
                    _to_minor_units(getattr(row, 'investment_amount_minor_units', None))
                    if wallet_type == 'investor'
                    else _to_minor_units(getattr(row, 'starting_amount_minor_units', None))
                )
                if initial_investment_minor_units is not None:
                    if initial_investment_minor_units >= 0:
                        account['initial_investment_cents'] = initial_investment_minor_units
                        account['investment_cents'] = initial_investment_minor_units
                    else:
                        _append_warning(
                            warnings,
                            seen_warnings,
                            f'Wallet "{wallet_name}" ({wallet_id}) has negative initial investment {initial_investment_minor_units}; initial_investment_cents was omitted.',
                        )

                balance_minor_units = _to_minor_units(getattr(row, 'balance_minor_units', None))
                if balance_minor_units is not None:
                    if balance_minor_units >= 0:
                        account['available_cents'] = balance_minor_units
                    else:
                        _append_warning(
                            warnings,
                            seen_warnings,
                            f'Wallet "{wallet_name}" ({wallet_id}) has negative balance {balance_minor_units}; available_cents was omitted because the new app does not accept negative imported balances.',
                        )
                else:
                    _append_warning(
                        warnings,
                        seen_warnings,
                        f'Wallet "{wallet_name}" ({wallet_id}) has no wallet_balances row; available_cents was omitted.',
                    )

                if wallet_type == 'investor':
                    _append_warning(
                        warnings,
                        seen_warnings,
                        'Legacy app has no standalone investor entity; exporter creates one synthetic investor per investor wallet.',
                    )
                    investor_legacy_id = f'wallet-investor-{wallet_id}'
                    investors.append({
                        'legacy_id': investor_legacy_id,
                        'name': wallet_name,
                        'contact_number': '',
                        'email': '',
                        'address': '',
                        'status': wallet_status,
                        'created_at': created_at,
                        'updated_at': updated_at,
                    })

                    investor_bps, company_bps = _resolve_profit_split(
                        wallet_id,
                        wallet_name,
                        getattr(row, 'investor_percentage', None),
                        getattr(row, 'user_percentage', None),
                        warnings,
                        seen_warnings,
                    )

                    account['legacy_investor_id'] = investor_legacy_id
                    account['investor_profit_bps'] = investor_bps
                    account['company_profit_bps'] = company_bps

                accounts.append(account)
                exported_account_ids.add(wallet_id)

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
                wallet_id = _to_text(getattr(row, 'wallet_id', None)).strip()
                installment = {
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
                }
                if wallet_id:
                    installment['legacy_funding_account_id'] = wallet_id
                    if wallet_id not in exported_account_ids:
                        accounts.append({
                            'legacy_id': wallet_id,
                            'name': f'Archived legacy wallet {wallet_id}',
                            'type': 'company_account',
                            'status': 'archived',
                            'currency': 'RUB',
                        })
                        exported_account_ids.add(wallet_id)
                        _append_warning(
                            warnings,
                            seen_warnings,
                            f'Installments reference wallet {wallet_id}, but that wallet record is missing; exporter created an archived placeholder company account so the funding link can still import.',
                        )
                installments.append(installment)

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
                'investors': investors,
                'accounts': accounts,
                'clients': clients,
                'installments': installments,
                'payments': payments,
            }
            if warnings:
                payload['warnings'] = warnings

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
