import json
import os
import ydb
import jwt
import logging
import time
from typing import Optional, Tuple
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime, date

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
    try:
        logger.info(f"Handler started. Event keys: {list(event.keys())}")
        logger.info(f"Path parameters: {event.get('pathParameters', 'None')}")
        logger.info(f"Received update payment request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        # Get payment ID from path parameters
        payment_id = event['pathParameters']['id']
        logger.info(f"Extracted payment_id: {payment_id}")
        
        # Parse request body
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
        
        # --- Validation ---
        # paid_amount optional for backward compatibility; default to 0
        try:
            paid_delta = Decimal(str(body.get('paid_amount', 0)))
        except Exception:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "'paid_amount' must be a number"})}
        logger.info(f"UPDATE-PAYMENT: initial paid_delta={paid_delta} is_paid={body.get('is_paid', False)} paid_date={body.get('paid_date')}")

        # Optional flags
        is_paid = bool(body.get('is_paid', False))
        paid_date = None
        if body.get('paid_date'):
            try:
                paid_date = datetime.strptime(body['paid_date'], '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "Invalid 'paid_date' format. Expected YYYY-MM-DD."})}

        # Database connection
        endpoint = os.environ['YDB_ENDPOINT']
        database = os.environ['YDB_DATABASE']
        
        driver_config = ydb.DriverConfig(
            endpoint=endpoint,
            database=database,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True)
        
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            nonlocal payment_id  # Allow modification of payment_id from outer scope
            nonlocal paid_delta  # We may adjust delta (e.g., full cancellation)
            logger.info(f"Starting execute_query with payment_id: {payment_id}, user_id: {user_id}")
            
            # Lightweight two-step verification with retry to avoid join pressure and throttling
            get_payment_inst_q = session.prepare(
                """
                DECLARE $payment_id AS Utf8;
                SELECT installment_id FROM installment_payments WHERE id = $payment_id;
                """
            )
            check_installment_user_q = session.prepare(
                """
                DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT id FROM installments WHERE id = $installment_id AND user_id = $user_id;
                """
            )

            verify_result = None
            installment_id = None
            backoff = 0.15
            for attempt in range(5):
                try:
                    # Step 1: find installment_id by payment_id
                    res1 = session.transaction().execute(
                        get_payment_inst_q,
                        {'$payment_id': payment_id},
                        commit_tx=False
                    )
                    if res1[0].rows:
                        installment_id = res1[0].rows[0].installment_id
                        # Step 2: ensure this installment belongs to current user
                        res2 = session.transaction().execute(
                            check_installment_user_q,
                            {'$installment_id': installment_id, '$user_id': user_id},
                            commit_tx=False
                        )
                        verify_result = res2
                        break
                    else:
                        verify_result = res1  # empty rows
                        break
                except Exception as e:
                    msg = str(e)
                    if 'ResourceExhausted' in msg or 'RESOURCE_EXHAUSTED' in msg:
                        time.sleep(backoff)
                        backoff = min(backoff * 2, 1.0)
                        continue
                    logger.error(f"Verify step failed: {e}")
                    raise

            # Handle synthetic payment IDs (ending with _next)
            if (not verify_result or not verify_result[0].rows) and payment_id.endswith('_next'):
                installment_id = payment_id.replace('_next', '')
                logger.info(f"Detected synthetic payment ID. Looking for next unpaid payment in installment: {installment_id}")
                
                # Find the actual next unpaid payment for this installment
                # Ensure the installment belongs to the user
                inst_check_q = """
DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
SELECT id FROM installments WHERE id = $installment_id AND user_id = $user_id;
"""
                prepared_inst_check = session.prepare(inst_check_q)
                inst_rows = session.transaction().execute(
                    prepared_inst_check,
                    {'$installment_id': installment_id, '$user_id': user_id},
                    commit_tx=False
                )
                if not inst_rows[0].rows:
                    raise Exception("Installment not found or access denied")

                find_next_payment_query = """
DECLARE $installment_id AS Utf8;
SELECT id
FROM installment_payments
WHERE installment_id = $installment_id AND is_paid = false
ORDER BY due_date ASC
LIMIT 1;
"""
                
                logger.info(f"Find next payment query: {find_next_payment_query}")
                try:
                    prepared_next_query = session.prepare(find_next_payment_query)
                    logger.info("Next payment query prepared successfully")
                    next_payment_result = session.transaction().execute(
                        prepared_next_query,
                        {'$installment_id': installment_id},
                        commit_tx=False
                    )
                    logger.info("Next payment query executed successfully")
                except Exception as next_query_error:
                    logger.error(f"Next payment query execution failed: {next_query_error}")
                    logger.error(f"Query was: {find_next_payment_query}")
                    raise
                
                if not next_payment_result[0].rows:
                    logger.error(f"No unpaid payments found for installment: {installment_id}")
                    raise Exception("No unpaid payments found for this installment")
                
                # Update payment_id to the actual payment ID
                row = next_payment_result[0].rows[0]
                payment_id = row.id
                logger.info(f"Found actual payment ID: {payment_id} for installment: {installment_id}")
                
            elif not verify_result or not verify_result[0].rows:
                logger.error(f"Payment not found or access denied. payment_id: {payment_id}, user_id: {user_id}")
                raise Exception("Payment not found or access denied")
            else:
                # Already validated: we have installment_id from step 1
                if not installment_id:
                    # Fallback to join result structure (shouldn't happen now)
                    row = verify_result[0].rows[0]
                    installment_id = row.installment_id
                logger.info(f"Found installment_id: {installment_id} for payment_id: {payment_id}")

            
            # Prepare reusable queries outside transaction
            update_payment_query = session.prepare(
                """
                DECLARE $payment_id AS Utf8;
                DECLARE $paid_amount AS Decimal(22,9);
                DECLARE $has_set AS Bool;
                DECLARE $new_is_paid AS Bool;
                DECLARE $paid_date AS Optional<Date>;
                DECLARE $updated_at AS Timestamp;

                UPDATE installment_payments
                SET 
                    paid_amount = COALESCE(paid_amount, CAST(0 AS Decimal(22,9))) + $paid_amount,
                    is_paid = CASE WHEN $has_set THEN $new_is_paid ELSE is_paid END,
                    expected_amount = CASE WHEN $has_set AND $new_is_paid THEN CAST(0 AS Decimal(22,9)) ELSE expected_amount END,
                    paid_date = CASE 
                        WHEN $has_set AND $new_is_paid THEN $paid_date 
                        WHEN $has_set AND NOT $new_is_paid THEN NULL 
                        ELSE paid_date END,
                    updated_at = $updated_at
                WHERE id = $payment_id;
                """
            )

            get_installment_q = session.prepare(
                """
                DECLARE $installment_id AS Utf8;
                SELECT installment_price, wallet_id, user_id, installment_number, down_payment, monthly_payment
                FROM installments WHERE id = $installment_id;
                """
            )

            get_payments_q = session.prepare(
                """
                DECLARE $installment_id AS Utf8;
                SELECT id, payment_number, expected_amount,
                       COALESCE(paid_amount, CAST(0 AS Decimal(22,9))) AS paid_amount,
                       is_paid, due_date
                FROM installment_payments
                WHERE installment_id = $installment_id
                ORDER BY payment_number ASC;
                """
            )

            # Start transaction for atomic updates
            tx = session.transaction(ydb.SerializableReadWrite())

            # Get payments snapshot and installment price
            inst_rs = tx.execute(get_installment_q, {'$installment_id': installment_id})
            if not inst_rs[0].rows:
                raise Exception("Installment not found")
            installment_row = inst_rs[0].rows[0]
            installment_price = Decimal(str(installment_row.installment_price))
            installment_wallet_id = getattr(installment_row, 'wallet_id', None)
            installment_user_id = getattr(installment_row, 'user_id', None)
            base_down_payment = Decimal(str(getattr(installment_row, 'down_payment', '0')))
            base_monthly_payment = Decimal(str(getattr(installment_row, 'monthly_payment', '0')))

            payments_rs = tx.execute(get_payments_q, {'$installment_id': installment_id})
            payments = list(payments_rs[0].rows)
            current_idx = next((i for i, r in enumerate(payments) if r.id == payment_id), None)
            if current_idx is None:
                raise Exception("Payment not found after verification")

            curr = payments[current_idx]
            curr_paid = Decimal(str(curr.paid_amount))
            curr_expected = Decimal(str(curr.expected_amount))
            
            # Allow simple "set to unpaid" by sending is_paid=false with 0 amount: we convert it into a full cancellation
            if (paid_delta == Decimal('0')) and (body.get('is_paid') is False) and (curr_paid > Decimal('0')):
                paid_delta = -curr_paid
                logger.info(f"UPDATE-PAYMENT TX: full cancellation applied, new paid_delta={paid_delta}")

            new_paid = curr_paid + paid_delta
            if new_paid < Decimal('0'):
                raise Exception("Cancellation exceeds paid amount")
            overpay_excess = new_paid - curr_expected if new_paid > curr_expected and curr_expected > Decimal('0') else Decimal('0')

            # Determine if we should flip is_paid
            want_set = False
            new_is_paid = curr.is_paid
            if body.get('is_paid') is not None:
                want_set = True
                new_is_paid = bool(body.get('is_paid'))
            else:
                if paid_delta > Decimal('0') and curr_expected > Decimal('0') and new_paid >= curr_expected:
                    want_set = True
                    new_is_paid = True
                elif paid_delta < Decimal('0') and new_paid < curr_expected:
                    want_set = True
                    new_is_paid = False

            # If caller marks as paid, use provided paid_date; if unmark, paid_date cleared by query
            eff_paid_date = paid_date if (want_set and new_is_paid) else None

            tx.execute(
                update_payment_query,
                {
                    '$payment_id': payment_id,
                    '$paid_amount': paid_delta,
                    '$has_set': want_set,
                    '$new_is_paid': new_is_paid,
                    '$paid_date': eff_paid_date,
                    '$updated_at': datetime.utcnow()
                }
            )
            logger.info(f"UPDATE-PAYMENT TX: Payment {payment_id} delta={paid_delta} set_paid={want_set} -> {new_is_paid}")

            # Refresh payments after update
            payments_rs = tx.execute(get_payments_q, {'$installment_id': installment_id})
            payments = list(payments_rs[0].rows)

            # Recompute outstanding = installment_price - sum(actual paid)
            outstanding_total = installment_price
            for r in payments:
                outstanding_total -= Decimal(str(r.paid_amount))
            if outstanding_total < Decimal('0'):
                outstanding_total = Decimal('0')

            # Identify unpaid payments snapshot
            unpaid = [r for r in payments if not r.is_paid]

            if outstanding_total == Decimal('0'):
                # Mark all remaining unpaid as paid with zero expected
                mark_paid_q = session.prepare(
                    """
                    DECLARE $installment_id AS Utf8;
                    UPDATE installment_payments
                    SET is_paid = true,
                        expected_amount = CAST(0 AS Decimal(22,9)),
                        updated_at = CurrentUtcTimestamp()
                    WHERE installment_id = $installment_id AND is_paid = false;
                    """
                )
                tx.execute(mark_paid_q, {'$installment_id': installment_id})
            else:
                if len(unpaid) > 0:
                    # If we overpaid current payment, cascade the excess forward in order
                    if overpay_excess > Decimal('0'):
                        # Use payments snapshot ordered by payment_number already
                        cascade_q = session.prepare(
                            """
                            DECLARE $id AS Utf8;
                            DECLARE $exp AS Decimal(22,9);
                            DECLARE $paid AS Bool;
                            UPDATE installment_payments
                            SET expected_amount = $exp,
                                is_paid = CASE WHEN $paid THEN true ELSE is_paid END,
                                updated_at = CurrentUtcTimestamp()
                            WHERE id = $id;
                            """
                        )
                        # Find current payment_number
                        current_payment_number = next((r.payment_number for r in payments if r.id == payment_id), None)
                        for r in payments:
                            if overpay_excess <= Decimal('0'):
                                break
                            if r.is_paid:
                                continue
                            if r.payment_number <= current_payment_number:
                                continue
                            r_expected = Decimal(str(r.expected_amount))
                            if overpay_excess >= r_expected and r_expected > Decimal('0'):
                                # Fully cover this future payment
                                tx.execute(cascade_q, {'$id': r.id, '$exp': Decimal('0'), '$paid': True})
                                overpay_excess -= r_expected
                            else:
                                # Partially reduce this future payment
                                new_exp = (r_expected - overpay_excess) if r_expected > overpay_excess else Decimal('0')
                                fully_paid = new_exp == Decimal('0')
                                tx.execute(cascade_q, {'$id': r.id, '$exp': new_exp, '$paid': fully_paid})
                                overpay_excess = Decimal('0')

                        # After cascade, recompute if everything is covered
                        payments_rs2 = tx.execute(get_payments_q, {'$installment_id': installment_id})
                        payments2 = list(payments_rs2[0].rows)
                        outstanding_total2 = installment_price
                        for r in payments2:
                            outstanding_total2 -= Decimal(str(r.paid_amount))
                        if outstanding_total2 <= Decimal('0'):
                            mark_paid_q = session.prepare(
                                """
                                DECLARE $installment_id AS Utf8;
                                UPDATE installment_payments
                                SET is_paid = true,
                                    expected_amount = CAST(0 AS Decimal(22,9)),
                                    updated_at = CurrentUtcTimestamp()
                                WHERE installment_id = $installment_id AND is_paid = false;
                                """
                            )
                            tx.execute(mark_paid_q, {'$installment_id': installment_id})
                    else:
                        # No overpay: keep existing expected amounts; do not rebalance here
                        pass
            
            # Final reconciliation: restore expectations towards initial plan (down + monthly)
            # and fit to outstanding. When this operation is a payment, do NOT increase any
            # unpaid expected amounts above their current values (preserve prior reductions).
            payments_rs3 = tx.execute(get_payments_q, {'$installment_id': installment_id})
            payments3 = list(payments_rs3[0].rows)
            unpaid3 = [r for r in payments3 if not r.is_paid]
            if len(unpaid3) > 0:
                TWO = Decimal('0.01')
                # Compute outstanding based on paid amounts
                rem = installment_price
                for r in payments3:
                    rem -= Decimal(str(r.paid_amount))
                if rem < Decimal('0'):
                    rem = Decimal('0')

                # Helper to derive the initial expected amount for a payment
                def initial_expected_for(pmt):
                    if int(pmt.payment_number or 0) == 0:
                        return base_down_payment
                    return base_monthly_payment

                adj_q = session.prepare(
                    """
                    DECLARE $id AS Utf8;
                    DECLARE $exp AS Decimal(22,9);
                    UPDATE installment_payments
                    SET expected_amount = $exp,
                        updated_at = CurrentUtcTimestamp()
                    WHERE id = $id;
                    """
                )

                unpaid_sorted = sorted(unpaid3, key=lambda x: x.payment_number)
                # Determine operation type
                is_pay_operation = (paid_delta > Decimal('0')) or (want_set and new_is_paid)
                toggled_unmark_id = payment_id if (want_set and not new_is_paid) else None

                # Track assignments to use for remainder adjustment
                assigned = {}

                if (not is_pay_operation) and toggled_unmark_id is not None:
                    # Unmarking a payment: keep other unpaid months at their initial caps first,
                    # then assign the remainder to the toggled month. This yields patterns like 1/3/3.
                    rest = [r for r in unpaid_sorted if r.id != toggled_unmark_id]
                    # Assign non-toggled first up to their initial caps
                    for r in rest:
                        if rem <= Decimal('0'):
                            target = Decimal('0')
                        else:
                            cap = initial_expected_for(r).quantize(TWO, rounding=ROUND_HALF_UP)
                            target = min(cap, rem).quantize(TWO, rounding=ROUND_HALF_UP)
                        assigned[r.id] = target
                        tx.execute(adj_q, {'$id': r.id, '$exp': target})
                        rem = (rem - target).quantize(TWO, rounding=ROUND_HALF_UP)
                    # Now the toggled payment absorbs the remainder up to its cap
                    toggle_row = next(r for r in unpaid_sorted if r.id == toggled_unmark_id)
                    cap_toggle = initial_expected_for(toggle_row).quantize(TWO, rounding=ROUND_HALF_UP)
                    target_toggle = min(cap_toggle, rem).quantize(TWO, rounding=ROUND_HALF_UP)
                    assigned[toggle_row.id] = target_toggle
                    tx.execute(adj_q, {'$id': toggle_row.id, '$exp': target_toggle})
                    rem = (rem - target_toggle).quantize(TWO, rounding=ROUND_HALF_UP)
                else:
                    # Payment or generic case: restore left-to-right, but when paying do not increase above current expected.
                    for r in unpaid_sorted:
                        if rem <= Decimal('0'):
                            target = Decimal('0')
                        else:
                            cap = initial_expected_for(r).quantize(TWO, rounding=ROUND_HALF_UP)
                            if is_pay_operation:
                                cur_exp = Decimal(str(r.expected_amount)).quantize(TWO, rounding=ROUND_HALF_UP)
                                target = min(cap, rem, cur_exp).quantize(TWO, rounding=ROUND_HALF_UP)
                            else:
                                target = min(cap, rem).quantize(TWO, rounding=ROUND_HALF_UP)
                        assigned[r.id] = target
                        tx.execute(adj_q, {'$id': r.id, '$exp': target})
                        rem = (rem - target).quantize(TWO, rounding=ROUND_HALF_UP)

                # If remainder persists due to rounding, add it to the earliest unpaid (nearest due)
                if rem > Decimal('0') and len(unpaid_sorted) > 0:
                    first = unpaid_sorted[0]
                    # Use the value we just assigned, not the stale snapshot
                    first_exp = assigned.get(first.id, Decimal(str(first.expected_amount))).quantize(TWO, rounding=ROUND_HALF_UP)
                    final_exp = (first_exp + rem).quantize(TWO, rounding=ROUND_HALF_UP)
                    tx.execute(adj_q, {'$id': first.id, '$exp': final_exp})

            # Get payment statistics (within transaction to see the updated payment)
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
            
            if not stats_result[0].rows:
                # No payments exist yet, use default values
                paid_amount = 0.0
                total_payments = 0
                paid_payments = 0
                overdue_count = 0
                next_payment_date = None
                last_payment_date = None
            else:
                stats_row = stats_result[0].rows[0]
                paid_amount = stats_row.paid_amount
                total_payments = stats_row.total_payments
                paid_payments = stats_row.paid_payments
                overdue_count = stats_row.overdue_count
                next_payment_date = stats_row.next_payment_date
                last_payment_date = stats_row.last_payment_date
            
            remaining_amount = installment_price - paid_amount
            
            # Get next payment amount separately (within transaction)
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
            
            if next_amount_result[0].rows:
                next_payment_row = next_amount_result[0].rows[0]
                next_payment_amount = next_payment_row.expected_amount
                logger.info(f"Next unpaid payment: ID={next_payment_row.id}, amount={next_payment_amount}, due_date={next_payment_row.due_date}, is_paid={next_payment_row.is_paid}")
            else:
                next_payment_amount = None
                logger.info("No unpaid payments found")
            
            # Simple UPDATE with calculated values
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
            
            prepared_update_installment = session.prepare(update_installment_query)
            
            # Update calculated fields in installments table
            tx.execute(
                prepared_update_installment,
                {
                    '$installment_id': installment_id,
                    '$paid_amount': paid_amount,
                    '$remaining_amount': remaining_amount,
                    '$total_payments': total_payments,
                    '$paid_payments': paid_payments,
                    '$overdue_count': overdue_count,
                    '$next_payment_date': next_payment_date,
                    '$next_payment_amount': next_payment_amount,
                    '$last_payment_date': last_payment_date,
                    '$updated_at': datetime.utcnow()
                }
            )
            
            update_status_query = """
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
            
            prepared_update_status = session.prepare(update_status_query)
            
            # Update payment status based on calculated fields
            tx.execute(
                prepared_update_status,
                {'$installment_id': installment_id}
            )
            
            # If installment is linked to a wallet, update wallet ledger and aggregates
            if installment_wallet_id is not None and str(installment_wallet_id).strip() != '':
                # Only write ledger and move balance if there was a non-zero paid delta
                if paid_delta != Decimal('0'):
                    # Fetch current wallet balance/version and wallet params
                    wb_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8;
                        DECLARE $user_id AS Utf8;
                        SELECT balance_minor_units, version
                        FROM wallet_balances
                        WHERE wallet_id = $wallet_id AND user_id = $user_id;
                        """
                    )
                    w_q = session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8;
                        DECLARE $user_id AS Utf8;
                        SELECT type, investment_amount_minor_units, investor_percentage
                        FROM wallets
                        WHERE id = $wallet_id AND user_id = $user_id;
                        """
                    )

                    wb_rs = tx.execute(wb_q, {'$wallet_id': installment_wallet_id, '$user_id': installment_user_id})
                    w_rs = tx.execute(w_q, {'$wallet_id': installment_wallet_id, '$user_id': installment_user_id})
                    if wb_rs[0].rows:
                        wb_row = wb_rs[0].rows[0]
                        current_balance = int(wb_row.balance_minor_units or 0)
                        current_version = int(wb_row.version or 0)
                    else:
                        # If no balance row exists, skip wallet updates for safety
                        current_balance = None
                        current_version = None

                    wallet_type = None
                    investment_amount_mu = 0
                    investor_pct = Decimal('0')
                    if w_rs[0].rows:
                        wrow = w_rs[0].rows[0]
                        wallet_type = str(getattr(wrow, 'type', '') or '').lower()
                        try:
                            investment_amount_mu = int(getattr(wrow, 'investment_amount_minor_units', 0) or 0)
                        except Exception:
                            investment_amount_mu = 0
                        try:
                            investor_pct = Decimal(str(getattr(wrow, 'investor_percentage', 0) or 0))
                        except Exception:
                            investor_pct = Decimal('0')

                    # Insert ledger transaction (credit for positive, debit for negative)
                    import uuid
                    ledger_id = str(uuid.uuid4())
                    ledger_insert_q = session.prepare(
                            """
                            DECLARE $id AS Utf8;
                            DECLARE $wallet_id AS Utf8;
                            DECLARE $user_id AS Utf8;
                            DECLARE $amount AS Int64;
                            DECLARE $direction AS Utf8;
                            DECLARE $reference_id AS Utf8;
                            DECLARE $description AS Utf8;
                            DECLARE $now AS Timestamp;
                            INSERT INTO ledger_transactions (
                                id, wallet_id, user_id, direction, amount_minor_units, currency,
                                reference_type, reference_id, description, created_by, created_at
                            ) VALUES (
                                $id, $wallet_id, $user_id, $direction, $amount, CAST('RUB' AS Utf8),
                                CAST('installment' AS Utf8), $reference_id, $description, $user_id, $now
                            );
                            """
                        )
                    # Convert paid_delta to minor units (2 digits)
                    paid_minor_units = int((paid_delta * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                    if paid_minor_units != 0 and current_balance is not None:
                        logger.info(f"UPDATE-PAYMENT TX: ledger will write direction={'credit' if paid_minor_units>0 else 'debit'} amount_mu={paid_minor_units}")
                        direction = 'credit' if paid_minor_units > 0 else 'debit'
                        # Simple fixed descriptions
                        desc = 'Installment payment' if direction == 'credit' else 'Installment payment cancellation'
                        tx.execute(ledger_insert_q, {
                            '$id': ledger_id,
                            '$wallet_id': installment_wallet_id,
                            '$user_id': installment_user_id,
                            '$amount': paid_minor_units,
                            '$direction': direction,
                            '$reference_id': installment_id,
                            '$description': desc,
                            '$now': datetime.utcnow()
                        })

                        # Recompute aggregates for this wallet
                        # total_allocated = sum of remaining per linked installments (installment_price - sum(paid_amount))
                        total_alloc_rs = tx.execute(
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
                                        FROM installment_payments
                                        GROUP BY installment_id
                                    ) AS p ON p.installment_id = i.id
                                    WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id
                                );
                                """
                            ),
                            {'$wallet_id': installment_wallet_id, '$user_id': installment_user_id}
                        )
                        total_remaining_dec = Decimal('0')
                        if total_alloc_rs[0].rows:
                            total_remaining_dec = Decimal(str(total_alloc_rs[0].rows[0].total_remaining or 0))
                        total_alloc_mu = int((total_remaining_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                        # due_to_get = sum of the next unpaid payment per installment linked to this wallet
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
                        nd_rs = tx.execute(next_due_q, {'$wallet_id': installment_wallet_id, '$user_id': installment_user_id})
                        due_next_dec = Decimal('0')
                        if nd_rs[0].rows:
                            due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0))
                        due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                        # New balance and version
                        new_balance = current_balance + paid_minor_units
                        new_version = current_version + 1

                        # expected_revenue = sum(installment_price - cash_price) for linked installments (investor only)
                        exp_rev_rs = tx.execute(
                            session.prepare(
                                """
                                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                                SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum
                                FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                                """
                            ),
                            {'$wallet_id': installment_wallet_id, '$user_id': installment_user_id}
                        )
                        profit_sum = Decimal('0')
                        if exp_rev_rs[0].rows:
                            profit_sum = Decimal(str(exp_rev_rs[0].rows[0].profit_sum or 0))
                        expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                        wb_update_q = session.prepare(
                            """
                            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                            DECLARE $new_balance AS Int64; DECLARE $new_version AS Uint64;
                            DECLARE $total_alloc AS Int64; DECLARE $due_to_get AS Int64; DECLARE $exp_rev AS Int64; DECLARE $paid_mu AS Int64;
                            DECLARE $curr_version AS Uint64; DECLARE $now AS Timestamp;
                            UPDATE wallet_balances
                            SET balance_minor_units = $new_balance,
                                version = $new_version,
                                updated_at = $now,
                                total_allocated_minor_units = $total_alloc,
                                due_to_get_minor_units = $due_to_get,
                                expected_revenue_minor_units = $exp_rev,
                                paid_amount_minor_units = COALESCE(paid_amount_minor_units, 0) + $paid_mu
                            WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $curr_version;
                            """
                        )
                        upd_res = tx.execute(wb_update_q, {
                            '$wallet_id': installment_wallet_id,
                            '$user_id': installment_user_id,
                            '$new_balance': new_balance,
                            '$new_version': new_version,
                            '$total_alloc': total_alloc_mu,
                            '$due_to_get': due_to_get_mu,
                            '$exp_rev': expected_revenue_mu,
                            '$paid_mu': paid_minor_units,
                            '$curr_version': current_version,
                            '$now': datetime.utcnow()
                        })
                        ra = None
                        try:
                            ra = getattr(getattr(upd_res[0], 'stats', None), 'rows_affected', None)
                        except Exception:
                            ra = None
                        logger.info(f"UPDATE-PAYMENT TX: wallet_balances updated new_balance={new_balance} rows_affected={ra if ra is not None else 'unknown'} total_alloc_mu={total_alloc_mu} due_to_get_mu={due_to_get_mu} exp_rev_mu={expected_revenue_mu} paid_mu_delta={paid_minor_units}")
                        if ra is not None and ra == 0:
                            raise ydb.Aborted("Concurrent update to wallet balance detected.")

            # Get the updated installment data to return to the client
            updated_installment_query = """
DECLARE $installment_id AS Utf8;
SELECT 
    id, user_id, client_id, investor_id, product_name,
    cash_price, installment_price, down_payment, term_months, monthly_payment,
    down_payment_date, installment_start_date, installment_end_date,
    created_at, updated_at,
    client_name, investor_name, paid_amount, remaining_amount,
    next_payment_date, next_payment_amount, payment_status,
    overdue_count, total_payments, paid_payments, last_payment_date
FROM installments
WHERE id = $installment_id;
"""
            
            updated_installment_result = tx.execute(
                session.prepare(updated_installment_query),
                {'$installment_id': installment_id}
            )
            
            if not updated_installment_result[0].rows:
                raise Exception("Updated installment not found")
            
            updated_installment = updated_installment_result[0].rows[0]
            
            # Commit all changes atomically
            tx.commit()
            
            # Return the updated installment data
            return updated_installment
        
        try:
            updated_installment = pool.retry_operation_sync(execute_query)
        finally:
            driver.stop()
        
        # Use the exact same date conversion logic as list-installments
        def convert_timestamp(ts):
            if ts is None: return None
            return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else ts.isoformat()

        def convert_date(d):
            if d is None: return None
            if isinstance(d, date): return d.strftime('%Y-%m-%d')
            if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal()).strftime('%Y-%m-%d')
            return str(d)
        
        # Convert the updated installment to a dictionary for JSON serialization
        installment_data = {
            'id': updated_installment.id,
            'user_id': updated_installment.user_id,
            'client_id': updated_installment.client_id,
            'investor_id': updated_installment.investor_id,
            'product_name': updated_installment.product_name,
            'cash_price': float(updated_installment.cash_price),
            'installment_price': float(updated_installment.installment_price),
            'down_payment': float(updated_installment.down_payment),
            'term_months': updated_installment.term_months,
            'monthly_payment': float(updated_installment.monthly_payment),
            'down_payment_date': convert_date(updated_installment.down_payment_date),
            'installment_start_date': convert_date(updated_installment.installment_start_date),
            'installment_end_date': convert_date(updated_installment.installment_end_date),
            'created_at': convert_timestamp(updated_installment.created_at),
            'updated_at': convert_timestamp(updated_installment.updated_at),
            'client_name': updated_installment.client_name,
            'investor_name': updated_installment.investor_name,
            'paid_amount': float(updated_installment.paid_amount) if updated_installment.paid_amount else 0.0,
            'remaining_amount': float(updated_installment.remaining_amount) if updated_installment.remaining_amount else 0.0,
            'next_payment_date': convert_date(updated_installment.next_payment_date),
            'next_payment_amount': float(updated_installment.next_payment_amount) if updated_installment.next_payment_amount else 0.0,
            'payment_status': updated_installment.payment_status,
            'overdue_count': updated_installment.overdue_count if updated_installment.overdue_count else 0,
            'total_payments': updated_installment.total_payments if updated_installment.total_payments else 0,
            'paid_payments': updated_installment.paid_payments if updated_installment.paid_payments else 0,
            'last_payment_date': convert_date(updated_installment.last_payment_date)
        }
        
        logger.info(f"Updated installment payment: {payment_id}")
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({
                'message': 'Installment payment updated successfully',
                'installment': installment_data
            })
        }
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'error': 'Internal server error'})
        } 
