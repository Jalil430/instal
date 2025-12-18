import os
import json
import ydb
import jwt
import logging
from datetime import datetime, date, timedelta
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

class SecurityValidator:
    """Handles input validation and sanitization"""

    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize wallet update input data"""
        errors = []
        sanitized = {}

        # Define validation rules
        validation_rules = {
            'name': {
                'required': True,
                'type': str,
                'min_length': 1,
                'max_length': 100,
            },
            'type': {
                'required': True,
                'type': str,
                'allowed_values': ['personal', 'investor'],
            },
            'currency': {
                'required': False,
                'type': str,
                'default': 'RUB',
                'allowed_values': ['RUB'],
            },
            'status': {
                'required': False,
                'type': str,
                'default': 'active',
                'allowed_values': ['active', 'archived'],
            },
            # Personal wallet starting amount
            'starting_amount_minor_units': {
                'required': False,
                'type': int,
                'min_value': 0,
            },
            # Investor-specific fields
            'investment_amount_minor_units': {
                'required': False,
                'type': int,
                'min_value': 1,
            },
            'investor_percentage': {
                'required': False,
                'type': (int, float),
                'min_value': 0.0,
                'max_value': 100.0,
            },
            'user_percentage': {
                'required': False,
                'type': (int, float),
                'min_value': 0.0,
                'max_value': 100.0,
            },
            'investment_return_date': {
                'required': False,
                'type': str,
            },
        }

        wallet_type = data.get('type')
        if not wallet_type:
            # Get existing wallet type if not provided
            wallet_type = 'personal'  # Default fallback

        for field, rules in validation_rules.items():
            value = data.get(field)

            # Handle default values
            if value is None and 'default' in rules:
                value = rules['default']

            # Check if required field is present
            if rules['required'] and (value is None or value == ''):
                errors.append(f'{field} is required')
                continue

            # Skip validation for optional empty fields
            if not rules['required'] and (value is None or value == ''):
                if field in ['investment_amount_minor_units', 'investor_percentage', 'user_percentage', 'investment_return_date']:
                    sanitized[field] = None
                else:
                    sanitized[field] = rules.get('default')
                continue

            # Type validation
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be of correct type')
                continue

            # String validations
            if isinstance(value, str):
                # Length validation
                if 'min_length' in rules and len(value) < rules['min_length']:
                    errors.append(f'{field} must be at least {rules["min_length"]} characters')
                    continue

                if 'max_length' in rules and len(value) > rules['max_length']:
                    errors.append(f'{field} must be no more than {rules["max_length"]} characters')
                    continue

                # Allowed values validation
                if 'allowed_values' in rules and value not in rules['allowed_values']:
                    errors.append(f'{field} must be one of: {", ".join(rules["allowed_values"])}')
                    continue

                # Sanitize string
                sanitized[field] = value.strip()

            # Numeric validations
            elif isinstance(value, (int, float)):
                if 'min_value' in rules and value < rules['min_value']:
                    errors.append(f'{field} must be at least {rules["min_value"]}')
                    continue

                if 'max_value' in rules and value > rules['max_value']:
                    errors.append(f'{field} must be no more than {rules["max_value"]}')
                    continue

                sanitized[field] = value
            else:
                sanitized[field] = value

        # Wallet type specific validations
        if wallet_type == 'investor':
            required_investor_fields = ['investment_amount_minor_units', 'investor_percentage', 'user_percentage', 'investment_return_date']
            for field in required_investor_fields:
                if field not in sanitized or sanitized[field] is None:
                    errors.append(f'{field} is required for investor wallets')

            # Validate percentages sum to 100
            if 'investor_percentage' in sanitized and 'user_percentage' in sanitized:
                if sanitized['investor_percentage'] is not None and sanitized['user_percentage'] is not None:
                    total_percentage = sanitized['investor_percentage'] + sanitized['user_percentage']
                    if abs(total_percentage - 100.0) > 0.01:  # Allow small floating point errors
                        errors.append('Investor and user percentages must sum to 100%')

            # Validate return date format and future date
            if 'investment_return_date' in sanitized and sanitized['investment_return_date']:
                try:
                    return_date = datetime.fromisoformat(sanitized['investment_return_date'].replace('Z', '+00:00'))
                    if return_date <= datetime.now():
                        errors.append('Investment return date must be in the future')
                except ValueError:
                    errors.append('Investment return date must be in ISO format (YYYY-MM-DD)')
        elif wallet_type == 'personal':
            # Personal wallet specific validations
            # starting_amount_minor_units is optional for updates
            pass

        return sanitized, errors

def handler(event, context):
    """
    Yandex Cloud Function handler to update a wallet
    """
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        # Log request
        logger.info(f"Received wallet update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")

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

        # 3. Parse and validate request body
        try:
            raw_body = event.get('body', '{}')

            # Check if the body is Base64 encoded
            try:
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                # If Base64 decoding fails, try parsing as plain JSON
                body = json.loads(raw_body)

        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid JSON in request body'})
            }

        # 4. Input validation and sanitization
        # Support status-only toggle (archive/unarchive) to bypass full validation
        status_only = False
        desired_status = None
        try:
            keys_nonempty = [k for k, v in (body or {}).items() if v not in (None, '')]
        except Exception:
            keys_nonempty = list((body or {}).keys())
        if isinstance(body, dict) and 'status' in body and len(keys_nonempty) == 1:
            s = str(body.get('status', '')).strip().lower()
            if s in ('active', 'archived'):
                status_only = True
                desired_status = s

        if status_only:
            sanitized_data = {'status': desired_status}
            validation_errors = []
        else:
            sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
            if validation_errors:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})
                }

        # 5. Database operations
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

            def update_wallet(session):
                # First, verify wallet exists and belongs to user
                verify_query = """
                DECLARE $wallet_id AS Utf8;
                DECLARE $user_id AS Utf8;

                SELECT id, type, status
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

                # Prevent updating archived wallets, except status-only unarchive
                if current_status == 'archived' and not (status_only and desired_status == 'active') and sanitized_data.get('status') != 'archived':
                    return {
                        'statusCode': 400,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Cannot update archived wallet'})
                    }

                # Update wallet
                current_time = datetime.utcnow()

                if status_only:
                    upd_status_q = """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $status AS Utf8; DECLARE $updated_at AS Timestamp;
                    UPDATE wallets SET status = $status, updated_at = $updated_at WHERE id = $wallet_id AND user_id = $user_id;
                    """
                    session.transaction().execute(
                        session.prepare(upd_status_q),
                        {'$wallet_id': wallet_id, '$user_id': user_id, '$status': desired_status, '$updated_at': current_time},
                        commit_tx=True
                    )
                else:
                    update_query = """
                    DECLARE $wallet_id AS Utf8;
                    DECLARE $user_id AS Utf8;
                    DECLARE $name AS Utf8;
                    DECLARE $type AS Utf8;
                    DECLARE $currency AS Utf8;
                    DECLARE $status AS Utf8;
                    DECLARE $investment_amount_minor_units AS Int64?;
                    DECLARE $starting_amount_minor_units AS Int64?;
                    DECLARE $investor_percentage AS Decimal(5,2)?;
                    DECLARE $user_percentage AS Decimal(5,2)?;
                    DECLARE $investment_return_date AS Date?;
                    DECLARE $updated_at AS Timestamp;

                    UPDATE wallets
                    SET name = $name,
                        type = $type,
                        currency = $currency,
                        status = $status,
                        investment_amount_minor_units = $investment_amount_minor_units,
                        starting_amount_minor_units = $starting_amount_minor_units,
                        investor_percentage = $investor_percentage,
                        user_percentage = $user_percentage,
                        investment_return_date = $investment_return_date,
                        updated_at = $updated_at
                    WHERE id = $wallet_id AND user_id = $user_id;
                    """

                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(prepared_update, {
                        '$wallet_id': wallet_id,
                        '$user_id': user_id,
                        '$name': sanitized_data['name'],
                        '$type': sanitized_data['type'],
                        '$currency': sanitized_data['currency'],
                        '$status': sanitized_data['status'],
                        '$investment_amount_minor_units': sanitized_data.get('investment_amount_minor_units'),
                        '$starting_amount_minor_units': sanitized_data.get('starting_amount_minor_units'),
                        '$investor_percentage': sanitized_data.get('investor_percentage'),
                        '$user_percentage': sanitized_data.get('user_percentage'),
                        '$investment_return_date': datetime.fromisoformat(sanitized_data['investment_return_date'].replace('Z', '+00:00')).date() if sanitized_data.get('investment_return_date') else None,
                        '$updated_at': current_time,
                    }, commit_tx=True)

                # Get updated wallet data
                select_query = """
                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT
                    id, user_id, name, type, currency, status,
                    require_nonnegative, allow_partial_allocation,
                    investment_amount_minor_units, starting_amount_minor_units,
                    investor_percentage, user_percentage, investment_return_date,
                    created_at, updated_at
                FROM wallets
                WHERE id = $wallet_id AND user_id = $user_id;
                """

                prepared_select = session.prepare(select_query)
                result_sets = session.transaction().execute(
                    prepared_select,
                    {'$wallet_id': wallet_id, '$user_id': user_id},
                    commit_tx=True
                )

                updated_row = result_sets[0].rows[0]

                def _conv_ts(ts):
                    if ts is None:
                        return None
                    if isinstance(ts, int):
                        # YDB Timestamp in microseconds
                        return datetime.fromtimestamp(ts / 1_000_000).isoformat()
                    if hasattr(ts, 'isoformat'):
                        return ts.isoformat()
                    return str(ts)

                def _conv_date(dv):
                    if dv is None:
                        return None
                    if isinstance(dv, int):
                        # YDB Date as days since epoch
                        base = date(1970, 1, 1)
                        return (base + timedelta(days=int(dv))).isoformat()
                    if isinstance(dv, str):
                        return dv
                    if hasattr(dv, 'isoformat'):
                        return dv.isoformat()
                    return str(dv)

                investor_pct = updated_row['investor_percentage']
                user_pct = updated_row['user_percentage']

                wallet_data = {
                    'id': updated_row['id'],
                    'user_id': updated_row['user_id'],
                    'name': updated_row['name'],
                    'type': updated_row['type'],
                    'currency': updated_row['currency'],
                    'status': updated_row['status'],
                    'require_nonnegative': updated_row['require_nonnegative'],
                    'allow_partial_allocation': updated_row['allow_partial_allocation'],
                    'investment_amount_minor_units': updated_row['investment_amount_minor_units'],
                    'starting_amount_minor_units': updated_row['starting_amount_minor_units'],
                    'investor_percentage': float(investor_pct) if investor_pct is not None else None,
                    'user_percentage': float(user_pct) if user_pct is not None else None,
                    'investment_return_date': _conv_date(updated_row['investment_return_date']) if 'investment_return_date' in updated_row else None,
                    'created_at': _conv_ts(updated_row['created_at']),
                    'updated_at': _conv_ts(updated_row['updated_at']),
                }

                logger.info(f"Wallet {wallet_id} updated successfully")
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(wallet_data)
                }

            # Execute with session pool
            result = pool.retry_operation_sync(update_wallet)

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
