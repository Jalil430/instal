import os
import json
import uuid
import ydb
import jwt
import logging
import calendar
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, Tuple

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

def handler(event, context):
    """
    Yandex Cloud Function handler to create a new installment.
    """
    try:
        logger.info(f"Received create request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        try:
            raw_body = event.get('body', '{}')
            
            # Check if the body is Base64 encoded (common with Yandex Cloud Functions)
            try:
                # Try to decode as Base64 first
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                # If Base64 decoding fails, try parsing as plain JSON
                body = json.loads(raw_body)
        except json.JSONDecodeError:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON in request body'})}

        # Use authenticated user_id instead of body user_id for security
        body['user_id'] = user_id
        wallet_id_opt = (body.get('wallet_id') or '').strip()

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def create_installment_in_db(session):
                # Generate new installment ID
                installment_id = str(uuid.uuid4())
                
                # Convert dates from strings to date objects
                down_payment_date = datetime.strptime(body['down_payment_date'], '%Y-%m-%d').date()
                installment_start_date = datetime.strptime(body['installment_start_date'], '%Y-%m-%d').date()
                installment_end_date = datetime.strptime(body['installment_end_date'], '%Y-%m-%d').date()
                
                # Current timestamp
                now = datetime.utcnow()
                
                # Create a transaction first
                tx = session.transaction(ydb.SerializableReadWrite())
                
                # First, get client name for calculated fields
                client_query = """
                DECLARE $client_id AS Utf8;
                SELECT full_name FROM clients WHERE id = $client_id;
                """
                client_result = tx.execute(session.prepare(client_query), {'$client_id': body['client_id']})
                client_rows = client_result[0].rows if (client_result and len(client_result) > 0) else []
                client_name = client_rows[0].full_name if client_rows else 'Unknown Client'
                
                # No denormalized wallet_name stored anymore
                
                # Calculate initial values for calculated fields
                installment_price = Decimal(str(body['installment_price']))
                down_payment = Decimal(str(body['down_payment']))
                term_months = int(body['term_months'])
                
                # For new installments, paid_amount is 0, remaining_amount is full installment_price
                paid_amount = Decimal('0')
                remaining_amount = installment_price
                
                # Calculate next payment and status correctly
                today = datetime.utcnow().date()
                
                if down_payment > 0:
                    # If there's a down payment, it's the next payment
                    next_payment_date = down_payment_date
                    next_payment_amount = down_payment
                    
                    # Status based on down payment date
                    if down_payment_date < today:
                        payment_status = 'просрочено'  # Down payment is overdue
                    elif down_payment_date <= today:
                        payment_status = 'к оплате'  # Down payment is due today
                    else:
                        payment_status = 'предстоящий'  # Down payment is in future
                else:
                    # No down payment, first monthly payment is next
                    next_payment_date = installment_start_date
                    next_payment_amount = Decimal(str(body['monthly_payment']))
                    
                    # Status based on first monthly payment date
                    if installment_start_date < today:
                        payment_status = 'просрочено'  # First payment is overdue
                    elif installment_start_date <= today:
                        payment_status = 'к оплате'  # First payment is due today
                    else:
                        payment_status = 'предстоящий'  # First payment is in future
                
                # Calculate total payments count
                total_payments = term_months  # down payment (if any) + monthly payments
                paid_payments = 0
                overdue_count = 0
                
                # Determine installment_number
                manual_number = None
                try:
                    if 'installment_number' in body and body['installment_number'] not in (None, ''):
                        manual_number = int(body['installment_number'])
                        if manual_number <= 0:
                            manual_number = None
                except Exception:
                    manual_number = None

                if manual_number is None:
                    # Get current max for this user and increment
                    max_query = """
                    DECLARE $user_id AS Utf8;
                    SELECT MAX(installment_number) AS max_num FROM installments WHERE user_id = $user_id;
                    """
                    max_result = tx.execute(session.prepare(max_query), {'$user_id': body['user_id']})
                    max_rows = max_result[0].rows if (max_result and len(max_result) > 0) else []
                    if max_rows and hasattr(max_rows[0], 'max_num') and max_rows[0].max_num is not None:
                        new_number = int(max_rows[0].max_num) + 1
                    else:
                        new_number = 1
                else:
                    new_number = manual_number

                query = """
                DECLARE $id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $client_id AS Utf8;
                DECLARE $wallet_id AS Utf8?;
                DECLARE $product_name AS Utf8;
                DECLARE $cash_price AS Decimal(22,9);
                DECLARE $installment_price AS Decimal(22,9);
                DECLARE $down_payment AS Decimal(22,9);
                DECLARE $term_months AS Int32;
                DECLARE $down_payment_date AS Date;
                DECLARE $installment_start_date AS Date;
                DECLARE $installment_end_date AS Date;
                DECLARE $monthly_payment AS Decimal(22,9);
                DECLARE $installment_number AS Int32;
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;
                DECLARE $client_name AS Utf8;
                DECLARE $paid_amount AS Decimal(22,9);
                DECLARE $remaining_amount AS Decimal(22,9);
                DECLARE $next_payment_date AS Date;
                DECLARE $next_payment_amount AS Decimal(22,9);
                DECLARE $payment_status AS Utf8;
                DECLARE $overdue_count AS Int32;
                DECLARE $total_payments AS Int32;
                DECLARE $paid_payments AS Int32;
                
                INSERT INTO installments (
                    id,
                    user_id,
                    client_id,
                    wallet_id,
                    product_name,
                    cash_price,
                    installment_price,
                    down_payment,
                    term_months,
                    down_payment_date,
                    installment_start_date,
                    installment_end_date,
                    monthly_payment,
                    installment_number,
                    created_at,
                    updated_at,
                    client_name,
                    paid_amount,
                    remaining_amount,
                    next_payment_date,
                    next_payment_amount,
                    payment_status,
                    overdue_count,
                    total_payments,
                    paid_payments
                )
                VALUES (
                    $id,
                    $user_id,
                    $client_id,
                    $wallet_id,
                    $product_name,
                    $cash_price,
                    $installment_price,
                    $down_payment,
                    $term_months,
                    $down_payment_date,
                    $installment_start_date,
                    $installment_end_date,
                    $monthly_payment,
                    $installment_number,
                    $created_at,
                    $updated_at,
                    $client_name,
                    $paid_amount,
                    $remaining_amount,
                    $next_payment_date,
                    $next_payment_amount,
                    $payment_status,
                    $overdue_count,
                    $total_payments,
                    $paid_payments
                );
                """
                
                # Execute the query to create the installment
                tx.execute(
                    session.prepare(query),
                    {
                        '$id': installment_id,
                        '$user_id': body['user_id'],
                        '$client_id': body['client_id'],
                        '$wallet_id': wallet_id_opt if wallet_id_opt else None,
                        '$product_name': body['product_name'],
                        '$cash_price': Decimal(str(body['cash_price'])),
                        '$installment_price': installment_price,
                        '$down_payment': down_payment,
                        '$term_months': term_months,
                        '$down_payment_date': down_payment_date,
                        '$installment_start_date': installment_start_date,
                        '$installment_end_date': installment_end_date,
                        '$monthly_payment': Decimal(str(body['monthly_payment'])),
                        '$installment_number': new_number,
                        '$created_at': now,
                        '$updated_at': now,
                        '$client_name': client_name,
                        '$paid_amount': paid_amount,
                        '$remaining_amount': remaining_amount,
                        '$next_payment_date': next_payment_date,
                        '$next_payment_amount': next_payment_amount,
                        '$payment_status': payment_status,
                        '$overdue_count': overdue_count,
                        '$total_payments': total_payments,
                        '$paid_payments': paid_payments
                    }
                )

                # Now, create installment payments
                # Down payment
                if body['down_payment'] > 0:
                    down_payment_query = """
                    DECLARE $id AS Utf8;
                    DECLARE $installment_id AS Utf8;
                    DECLARE $payment_number AS Int32;
                    DECLARE $due_date AS Date;
                    DECLARE $expected_amount AS Decimal(22,9);
                    DECLARE $is_paid AS Bool;
                    DECLARE $paid_date AS Optional<Date>;
                    DECLARE $created_at AS Timestamp;
                    DECLARE $updated_at AS Timestamp;

                    INSERT INTO installment_payments (id, installment_id, payment_number, due_date, expected_amount, is_paid, paid_date, created_at, updated_at)
                    VALUES ($id, $installment_id, $payment_number, $due_date, $expected_amount, $is_paid, $paid_date, $created_at, $updated_at);
                    """
                    tx.execute(
                        session.prepare(down_payment_query),
                        {
                            '$id': str(uuid.uuid4()),
                            '$installment_id': installment_id,
                            '$payment_number': 0,
                            '$due_date': down_payment_date,
                            '$expected_amount': Decimal(str(body['down_payment'])),
                            '$is_paid': False,
                            '$paid_date': None,
                            '$created_at': now,
                            '$updated_at': now
                        }
                    )
                    logger.info(f"CREATE-INSTALLMENT TX: down-payment schedule row created installment_id={installment_id} amount={body['down_payment']}")

                # Monthly payments
                monthly_payment_query = """
                DECLARE $id AS Utf8;
                DECLARE $installment_id AS Utf8;
                DECLARE $payment_number AS Int32;
                DECLARE $due_date AS Date;
                DECLARE $expected_amount AS Decimal(22,9);
                DECLARE $is_paid AS Bool;
                DECLARE $paid_date AS Optional<Date>;
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;

                INSERT INTO installment_payments (id, installment_id, payment_number, due_date, expected_amount, is_paid, paid_date, created_at, updated_at)
                VALUES ($id, $installment_id, $payment_number, $due_date, $expected_amount, $is_paid, $paid_date, $created_at, $updated_at);
                """
                
                term_months = int(body['term_months'])
                monthly_payment = Decimal(str(body['monthly_payment']))
                
                # Correct logic: if there's a down payment, it counts as part of the term
                # So for 6-month term with down payment: 1 down payment + 5 monthly payments = 6 total
                monthly_payments_count = term_months - 1 if body['down_payment'] > 0 else term_months
                
                for i in range(1, monthly_payments_count + 1):
                    # Calculate due date for each monthly payment
                    # Monthly payment 1: Always due on installment start date (months_to_add = 0)
                    # Monthly payment 2: Due 1 month after installment start date (months_to_add = 1)
                    # Monthly payment 3: Due 2 months after installment start date (months_to_add = 2)
                    # Down payment does NOT affect monthly payment timing
                    months_to_add = i - 1
                    total_months = installment_start_date.month + months_to_add
                    year = installment_start_date.year + (total_months - 1) // 12
                    month = (total_months - 1) % 12 + 1
                    
                    # To determine the day, we need to know the number of days in the target month
                    last_day_of_month = calendar.monthrange(year, month)[1]
                    day = min(body.get('payment_due_day', installment_start_date.day), last_day_of_month)

                    final_due_date = date(year, month, day)

                    tx.execute(
                        session.prepare(monthly_payment_query),
                        {
                            '$id': str(uuid.uuid4()),
                            '$installment_id': installment_id,
                            '$payment_number': i,
                            '$due_date': final_due_date,
                            '$expected_amount': monthly_payment,
                            '$is_paid': False,
                            '$paid_date': None,
                            '$created_at': now,
                            '$updated_at': now
                        }
                    )
                logger.info(f"CREATE-INSTALLMENT TX: monthly schedule created installment_id={installment_id} count={monthly_payments_count}")

                # Auto-mark down payment regardless of wallet presence
                if body['down_payment'] > 0:
                    tx.execute(
                        session.prepare(
                            """
                            DECLARE $installment_id AS Utf8; DECLARE $amount AS Decimal(22,9); DECLARE $date AS Date; DECLARE $ts AS Timestamp;
                            UPDATE installment_payments SET paid_amount = COALESCE(paid_amount, CAST(0 AS Decimal(22,9))) + $amount, is_paid = true, paid_date = $date, updated_at = $ts
                            WHERE installment_id = $installment_id AND payment_number = 0;
                            """
                        ),
                        {'$installment_id': installment_id, '$amount': Decimal(str(body['down_payment'])), '$date': down_payment_date, '$ts': now}
                    )
                    logger.info("CREATE-INSTALLMENT TX: down-payment marked paid (schedule)")

                # If wallet_id provided, perform allocation of cash price, handle ledger entries, and update aggregates
                if wallet_id_opt:
                    # Validate wallet exists and active for this user
                    wallet_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT type FROM wallets WHERE id = $wallet_id AND user_id = $user_id AND status = 'active';
                        """
                    )
                    w_rs = tx.execute(wallet_q, {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']})
                    if not (w_rs and len(w_rs) > 0 and w_rs[0].rows):
                        tx.rollback()
                        return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet not found or inactive'})}

                    # Fetch wallet balance/version
                    wb_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                        """
                    )
                    logger.info("CREATE-INSTALLMENT TX: ledger debit created for cash price")
                    wb_rs = tx.execute(wb_q, {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']})
                    if not (wb_rs and len(wb_rs) > 0 and wb_rs[0].rows):
                        tx.rollback()
                        return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Wallet balance not initialized'})}
                    current_balance = int(wb_rs[0].rows[0].balance_minor_units or 0)
                    current_version = int(wb_rs[0].rows[0].version or 0)

                    from decimal import ROUND_HALF_UP as RHU
                    cash_price_mu = int((Decimal(str(body['cash_price'])) * Decimal('100')).quantize(Decimal('1'), rounding=RHU))
                    logger.info(f"CREATE-INSTALLMENT TX: allocation preparing, cash_price_mu={cash_price_mu}")
                    # Allow creating installments even with insufficient wallet balance
                    # This will result in negative wallet balance if needed

                    import uuid as _uuid
                    # Allocation record (active)
                    alloc_id = str(_uuid.uuid4())
                    tx.execute(
                        session.prepare(
                            """
                            DECLARE $id AS Utf8; DECLARE $installment_id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amount AS Int64; DECLARE $created_at AS Timestamp;
                            INSERT INTO installment_allocations (id, installment_id, wallet_id, user_id, amount_minor_units, transaction_id, status, created_at)
                            VALUES ($id, $installment_id, $wallet_id, $user_id, $amount, NULL, 'active', $created_at);
                            """
                        ),
                        {'$id': alloc_id, '$installment_id': installment_id, '$wallet_id': wallet_id_opt, '$user_id': body['user_id'], '$amount': cash_price_mu, '$created_at': now}
                    )

                    # Ledger debit for cash purchase
                    debit_id = str(_uuid.uuid4())
                    tx.execute(
                        session.prepare(
                            """
                            DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                            INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                            VALUES ($id, $wallet_id, $user_id, 'debit', $amt, CAST('RUB' AS Utf8), CAST('installment' AS Utf8), $ref, $desc, $user_id, $ts);
                            """
                        ),
                        {'$id': debit_id, '$wallet_id': wallet_id_opt, '$user_id': body['user_id'], '$amt': cash_price_mu, '$ref': installment_id, '$ts': now, '$desc': 'Installment cash purchase'}
                    )

                    new_balance = current_balance - cash_price_mu
                    paid_mu = 0
                    if body['down_payment'] > 0:
                        dp_mu = int((Decimal(str(body['down_payment'])) * Decimal('100')).quantize(Decimal('1'), rounding=RHU))
                        # Ledger credit for down payment
                        credit_id = str(_uuid.uuid4())
                        tx.execute(
                            session.prepare(
                                """
                                DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                                INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                                VALUES ($id, $wallet_id, $user_id, 'credit', $amt, CAST('RUB' AS Utf8), CAST('installment' AS Utf8), $ref, $desc, $user_id, $ts);
                                """
                            ),
                            {'$id': credit_id, '$wallet_id': wallet_id_opt, '$user_id': body['user_id'], '$amt': dp_mu, '$ref': installment_id, '$ts': now, '$desc': 'Down payment received'}
                        )
                        logger.info("CREATE-INSTALLMENT TX: ledger credit created for down payment")
                        new_balance += dp_mu
                        paid_mu += dp_mu

                    # Recompute aggregates for wallet: total remaining, due_to_get, expected revenue
                    total_rem_rs = tx.execute(
                        session.prepare(
                            """
                            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                            SELECT COALESCE(SUM(rem), CAST(0 AS Decimal(22,9))) AS total_remaining
                            FROM (
                                SELECT i.id,
                                  CAST(i.installment_price AS Decimal(22,9)) - CAST(COALESCE(p.paid_sum, CAST(0 AS Decimal(22,9))) AS Decimal(22,9)) AS rem
                                FROM installments i
                                LEFT JOIN (
                                    SELECT installment_id, COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
                                    FROM installment_payments GROUP BY installment_id
                                ) AS p ON p.installment_id = i.id
                                WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id
                            );
                            """
                        ),
                        {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']}
                    )
                    tr_rows = total_rem_rs[0].rows if (total_rem_rs and len(total_rem_rs) > 0) else []
                    total_remaining_dec = Decimal(str(tr_rows[0].total_remaining or 0)) if tr_rows else Decimal('0')
                    total_alloc_mu = int((total_remaining_dec * Decimal('100')).quantize(Decimal('1'), rounding=RHU))

                    # due_to_get = sum of next unpaid payment per installment linked to this wallet
                    next_due_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(
                          CAST(ip.expected_amount AS Decimal(22,9)) - CAST(COALESCE(ip.paid_amount, CAST(0 AS Decimal(22,9))) AS Decimal(22,9))
                        ), CAST(0 AS Decimal(22,9))) AS due_next_sum
                        FROM installment_payments ip
                        INNER JOIN installments i ON i.id = ip.installment_id
                        INNER JOIN (
                          SELECT ip2.installment_id AS inst_id, MIN(ip2.due_date) AS next_due
                          FROM installment_payments ip2
                          INNER JOIN installments i2 ON i2.id = ip2.installment_id
                          WHERE i2.wallet_id = $wallet_id AND i2.user_id = $user_id AND ip2.is_paid = false
                          GROUP BY ip2.installment_id
                        ) nu ON nu.inst_id = ip.installment_id AND ip.due_date = nu.next_due
                        WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """
                    )
                    nd_rs = tx.execute(next_due_q, {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']})
                    due_next_dec = Decimal('0')
                    if nd_rs[0].rows:
                        due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0))
                    due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=RHU))

                    exp_rev_rs = tx.execute(
                        session.prepare(
                            """
                            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                            SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum
                            FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                            """
                        ),
                        {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']}
                    )
                    er_rows = exp_rev_rs[0].rows if (exp_rev_rs and len(exp_rev_rs) > 0) else []
                    profit_sum = Decimal(str(er_rows[0].profit_sum or 0)) if er_rows else Decimal('0')
                    expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=RHU))

                    # Spent on products = sum of cash_price
                    spent_rs = tx.execute(
                        session.prepare(
                            """
                            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                            SELECT COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
                            FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                            """
                        ),
                        {'$wallet_id': wallet_id_opt, '$user_id': body['user_id']}
                    )
                    spent_sum = Decimal(str(spent_rs[0].rows[0].spent_sum or 0)) if spent_rs[0].rows else Decimal('0')
                    spent_mu = int((spent_sum * Decimal('100')).quantize(Decimal('1'), rounding=RHU))

                    # Update wallet balance and aggregates
                    upd_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $new_balance AS Int64; DECLARE $new_version AS Uint64; DECLARE $curr_version AS Uint64; DECLARE $now AS Timestamp;
                        DECLARE $total_alloc AS Int64; DECLARE $due_to_get AS Int64; DECLARE $exp_rev AS Int64; DECLARE $paid_mu AS Int64; DECLARE $spent_mu AS Int64;
                        UPDATE wallet_balances SET balance_minor_units = $new_balance, version = $new_version, updated_at = $now,
                          total_allocated_minor_units = $total_alloc, due_to_get_minor_units = $due_to_get,
                          expected_revenue_minor_units = $exp_rev,
                          spent_on_products_minor_units = $spent_mu,
                          paid_amount_minor_units = COALESCE(paid_amount_minor_units, 0) + $paid_mu
                        WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $curr_version;
                        """
                    )
                    upd_res = tx.execute(upd_q, {'$wallet_id': wallet_id_opt, '$user_id': body['user_id'], '$new_balance': new_balance, '$new_version': current_version + 1, '$curr_version': current_version, '$now': now, '$total_alloc': total_alloc_mu, '$due_to_get': due_to_get_mu, '$exp_rev': expected_revenue_mu, '$paid_mu': paid_mu, '$spent_mu': spent_mu})
                    try:
                        ra = getattr(getattr(upd_res[0], 'stats', None), 'rows_affected', None) if (upd_res and len(upd_res) > 0) else None
                    except Exception:
                        ra = None
                    logger.info(f"CREATE-INSTALLMENT TX: wallet_balances updated new_balance={new_balance} rows_affected={(ra if ra is not None else 'unknown')} total_alloc_mu={total_alloc_mu} due_to_get_mu={due_to_get_mu} exp_rev_mu={expected_revenue_mu} paid_mu_delta={paid_mu}")
                    if ra is not None and ra == 0:
                        tx.rollback()
                        return {'statusCode': 409, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Concurrent wallet update detected'})}

                
                # Recompute installment aggregates and status
                payment_stats_query = """
DECLARE $installment_id AS Utf8;
SELECT 
    COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) as paid_amount,
    CAST(COUNT(*) AS Int32) as total_payments,
    CAST(SUM(CASE WHEN is_paid = true THEN CAST(1 AS Int32) ELSE CAST(0 AS Int32) END) AS Int32) as paid_payments,
    CAST(SUM(CASE WHEN is_paid = false AND due_date < CurrentUtcDate() THEN CAST(1 AS Int32) ELSE CAST(0 AS Int32) END) AS Int32) as overdue_count,
    MIN(CASE WHEN is_paid = false THEN due_date ELSE NULL END) as next_payment_date,
    MAX(CASE WHEN is_paid = true THEN paid_date ELSE NULL END) as last_payment_date
FROM installment_payments
WHERE installment_id = $installment_id;
"""
                stats_result = tx.execute(
                    session.prepare(payment_stats_query),
                    {'$installment_id': installment_id}
                )
                if stats_result and len(stats_result) > 0 and stats_result[0].rows:
                    srow = stats_result[0].rows[0]
                    paid_amount_stat = srow.paid_amount
                    total_payments_stat = srow.total_payments
                    paid_payments_stat = srow.paid_payments
                    overdue_count_stat = srow.overdue_count
                    next_payment_date_stat = srow.next_payment_date
                    last_payment_date_stat = srow.last_payment_date
                else:
                    from decimal import Decimal as _D
                    paid_amount_stat = _D('0')
                    total_payments_stat = 0
                    paid_payments_stat = 0
                    overdue_count_stat = 0
                    next_payment_date_stat = None
                    last_payment_date_stat = None

                remaining_amount_stat = installment_price - paid_amount_stat

                next_amount_query = """
DECLARE $installment_id AS Utf8;
SELECT id, expected_amount, due_date, is_paid FROM installment_payments 
WHERE installment_id = $installment_id AND is_paid = false 
ORDER BY due_date ASC LIMIT 1;
"""
                next_amount_result = tx.execute(
                    session.prepare(next_amount_query),
                    {'$installment_id': installment_id}
                )
                if next_amount_result and len(next_amount_result) > 0 and next_amount_result[0].rows:
                    nr = next_amount_result[0].rows[0]
                    next_payment_amount_stat = nr.expected_amount
                else:
                    next_payment_amount_stat = None

                update_installment_query = """
DECLARE $installment_id AS Utf8;
DECLARE $paid_amount AS Decimal(22,9);
DECLARE $remaining_amount AS Decimal(22,9);
DECLARE $total_payments AS Int32;
DECLARE $paid_payments AS Int32;
DECLARE $overdue_count AS Int32;
DECLARE $next_payment_date AS Date?;
DECLARE $next_payment_amount AS Decimal(22,9)?;
DECLARE $last_payment_date AS Date?;
DECLARE $updated_at AS Timestamp;

UPDATE installments SET
    paid_amount = $paid_amount,
    remaining_amount = $remaining_amount,
    total_payments = $total_payments,
    paid_payments = $paid_payments,
    overdue_count = $overdue_count,
    next_payment_date = $next_payment_date,
    next_payment_amount = $next_payment_amount,
    last_payment_date = $last_payment_date,
    updated_at = $updated_at
WHERE id = $installment_id;
"""
                tx.execute(
                    session.prepare(update_installment_query),
                    {
                        '$installment_id': installment_id,
                        '$paid_amount': paid_amount_stat,
                        '$remaining_amount': remaining_amount_stat,
                        '$total_payments': total_payments_stat,
                        '$paid_payments': paid_payments_stat,
                        '$overdue_count': overdue_count_stat,
                        '$next_payment_date': next_payment_date_stat,
                        '$next_payment_amount': next_payment_amount_stat,
                        '$last_payment_date': last_payment_date_stat,
                        '$updated_at': now
                    }
                )

                tx.execute(
                    session.prepare(
                        """
                        DECLARE $installment_id AS Utf8;
                        UPDATE installments SET
                            payment_status = CASE
                                WHEN overdue_count > 0 THEN CAST('просрочено' AS Utf8)
                                WHEN paid_payments = total_payments AND total_payments > 0 THEN CAST('оплачено' AS Utf8)
                                WHEN next_payment_date IS NOT NULL AND next_payment_date <= CurrentUtcDate() THEN CAST('к оплате' AS Utf8)
                                ELSE CAST('предстоящий' AS Utf8)
                            END
                        WHERE id = $installment_id;
                        """
                    ),
                    {'$installment_id': installment_id}
                )

                # Commit the transaction
                tx.commit()
                
                logger.info(f"Created installment with ID: {installment_id} and its payment schedule")
                return {'statusCode': 201, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'id': installment_id, 'message': 'Installment and payments created successfully'})}

            return pool.retry_operation_sync(create_installment_in_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 
