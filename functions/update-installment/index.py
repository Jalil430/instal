import os
import json
import ydb
import jwt
import logging
import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
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

def _update_wallet_aggregates(session, tx, wallet_id, user_id, exclude_installment_id, current_version, current_balance, now):
    """Helper function to update wallet aggregates - optimized but preserving all functionality"""
    
    # Optimize by combining the first 3 queries into a single query
    if exclude_installment_id:
        combined_query = """
        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $exclude_id AS Utf8;
        SELECT 
            COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(COALESCE(p.paid_sum, CAST(0 AS Decimal(22,9))) AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS total_remaining,
            COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum,
            COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
        FROM installments i 
        LEFT JOIN (
            SELECT installment_id, COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
            FROM installment_payments GROUP BY installment_id
        ) AS p ON p.installment_id = i.id
        WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id AND i.id != $exclude_id;
        """
        combined_params = {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': exclude_installment_id}
    else:
        combined_query = """
        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
        SELECT 
            COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(COALESCE(p.paid_sum, CAST(0 AS Decimal(22,9))) AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS total_remaining,
            COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum,
            COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
        FROM installments i 
        LEFT JOIN (
            SELECT installment_id, COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
            FROM installment_payments GROUP BY installment_id
        ) AS p ON p.installment_id = i.id
        WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
        """
        combined_params = {'$wallet_id': wallet_id, '$user_id': user_id}
    
    # Execute combined query
    combined_rs = tx.execute(session.prepare(combined_query), combined_params)
    
    if combined_rs[0].rows:
        row = combined_rs[0].rows[0]
        total_remaining_dec = Decimal(str(row.total_remaining or 0))
        profit_sum = Decimal(str(row.profit_sum or 0))
        spent_sum_dec = Decimal(str(row.spent_sum or 0))
    else:
        total_remaining_dec = profit_sum = spent_sum_dec = Decimal('0')
    
    total_alloc_mu = int((total_remaining_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    spent_mu = int((spent_sum_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    
    # Keep the original due_to_get calculation but optimize it
    if exclude_installment_id:
        next_due_q = session.prepare(
            """
            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $exclude_id AS Utf8;
            SELECT COALESCE(SUM(
              CAST(ip.expected_amount AS Decimal(22,9)) - CAST(COALESCE(ip.paid_amount, CAST(0 AS Decimal(22,9))) AS Decimal(22,9))
            ), CAST(0 AS Decimal(22,9))) AS due_next_sum
            FROM installment_payments ip
            INNER JOIN installments i ON i.id = ip.installment_id
            INNER JOIN (
              SELECT ip2.installment_id AS inst_id, MIN(ip2.due_date) AS next_due
              FROM installment_payments ip2
              INNER JOIN installments i2 ON i2.id = ip2.installment_id
              WHERE i2.wallet_id = $wallet_id AND i2.user_id = $user_id AND ip2.is_paid = false AND i2.id != $exclude_id
              GROUP BY ip2.installment_id
            ) nu ON nu.inst_id = ip.installment_id AND ip.due_date = nu.next_due
            WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id AND i.id != $exclude_id;
            """
        )
        nd_rs = tx.execute(next_due_q, {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': exclude_installment_id})
    else:
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
        nd_rs = tx.execute(next_due_q, {'$wallet_id': wallet_id, '$user_id': user_id})
    
    due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0)) if nd_rs[0].rows else Decimal('0')
    due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    
    # Update wallet balance and aggregates
    tx.execute(
        session.prepare(
            """
            DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
            DECLARE $new_balance AS Int64; DECLARE $new_version AS Uint64;
            DECLARE $total_alloc AS Int64; DECLARE $due_to_get AS Int64; DECLARE $exp_rev AS Int64; DECLARE $spent_mu AS Int64;
            DECLARE $curr_version AS Uint64; DECLARE $now AS Timestamp;
            UPDATE wallet_balances
            SET balance_minor_units = $new_balance,
                version = $new_version,
                updated_at = $now,
                total_allocated_minor_units = $total_alloc,
                due_to_get_minor_units = $due_to_get,
                expected_revenue_minor_units = $exp_rev,
                spent_on_products_minor_units = $spent_mu
            WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $curr_version;
            """
        ),
        {
            '$wallet_id': wallet_id,
            '$user_id': user_id,
            '$new_balance': current_balance,
            '$new_version': int(current_version) + 1,
            '$total_alloc': total_alloc_mu,
            '$due_to_get': due_to_get_mu,
            '$exp_rev': expected_revenue_mu,
            '$spent_mu': spent_mu,
            '$curr_version': int(current_version),
            '$now': now
        }
    )

def handler(event, context):
    """
    Yandex Cloud Function handler to update an installment.
    """
    try:
        logger.info(f"Received update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        # Get installment ID from path parameters
        installment_id = event['pathParameters']['id']
        
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

        logger.info(f"UPDATE-INSTALLMENT: Request body: {body}")

        # Define allowed fields for editing
        allowed_fields = {'client_id', 'wallet_id', 'installment_number', 'product_name'}
        
        # Check for any disallowed fields
        provided_fields = set(body.keys())
        disallowed_fields = provided_fields - allowed_fields
        if disallowed_fields:
            return {
                'statusCode': 400, 
                'headers': {'Content-Type': 'application/json'}, 
                'body': json.dumps({
                    'error': f'Only these fields can be edited: {", ".join(sorted(allowed_fields))}. Disallowed fields: {", ".join(sorted(disallowed_fields))}'
                })
            }
        
        # Validate that at least one field is being updated
        if not provided_fields:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'At least one field must be provided for update'})}

        # Extract and validate fields
        new_client_id = body.get('client_id')
        new_wallet_id = body.get('wallet_id')
        new_installment_number = body.get('installment_number')
        new_product_name = body.get('product_name')
        
        # Normalize wallet_id (empty string = None)
        if new_wallet_id == '':
            new_wallet_id = None
            
        # Validate installment_number if provided
        if new_installment_number is not None:
            try:
                new_installment_number = int(new_installment_number)
                if new_installment_number <= 0:
                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'installment_number must be positive'})}
            except (ValueError, TypeError):
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'installment_number must be a valid number'})}

        # Validate product_name if provided
        if new_product_name is not None and not str(new_product_name).strip():
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'product_name cannot be empty'})}

        logger.info(f"UPDATE-INSTALLMENT: client_id={new_client_id}, wallet_id={new_wallet_id}, installment_number={new_installment_number}, product_name={new_product_name}")

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def update_installment_in_db(session):
                try:
                    # Start transaction
                    tx = session.transaction(ydb.SerializableReadWrite())
                    now = datetime.utcnow()
                    logger.info(f"UPDATE-INSTALLMENT: Starting transaction for installment {installment_id}")
                    
                    # Get current installment data
                    get_installment_query = """
                    DECLARE $installment_id AS Utf8;
                    DECLARE $user_id AS Utf8;
                    SELECT id, client_id, wallet_id, installment_number, product_name, installment_price, cash_price, paid_amount, remaining_amount
                    FROM installments 
                    WHERE id = $installment_id AND user_id = $user_id;
                    """
                    
                    result = tx.execute(
                        session.prepare(get_installment_query),
                        {'$installment_id': installment_id, '$user_id': user_id}
                    )
                    
                    if not result[0].rows:
                        tx.rollback()
                        return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Installment not found'})}
                    
                    current_installment = result[0].rows[0]
                    old_client_id = getattr(current_installment, 'client_id', None)
                    old_wallet_id = getattr(current_installment, 'wallet_id', None)
                    old_installment_number = getattr(current_installment, 'installment_number', None)
                    old_product_name = getattr(current_installment, 'product_name', None)
                    cash_price = Decimal(str(current_installment.cash_price))
                    
                    logger.info(f"UPDATE-INSTALLMENT: Current installment - client_id={old_client_id}, wallet_id={old_wallet_id}, number={old_installment_number}, product={old_product_name}")
                    
                    # Use current values if new values not provided
                    final_client_id = new_client_id if new_client_id is not None else old_client_id
                    final_wallet_id = new_wallet_id if 'wallet_id' in body else old_wallet_id
                    final_installment_number = new_installment_number if new_installment_number is not None else old_installment_number
                    final_product_name = new_product_name if new_product_name is not None else old_product_name
                    
                    # Combine validation queries for better performance
                    validation_queries = []
                    validation_params = {}
                    
                    # Validate client exists if client_id is being changed
                    if new_client_id is not None and new_client_id != old_client_id:
                        validation_queries.append("SELECT 'client' as check_type, COUNT(*) as count FROM clients WHERE id = $client_id AND user_id = $user_id")
                        validation_params['$client_id'] = new_client_id
                    
                    # Check for installment_number uniqueness if it's being changed
                    if new_installment_number is not None and new_installment_number != old_installment_number:
                        if validation_queries:
                            validation_queries.append("UNION ALL SELECT 'installment_number' as check_type, COUNT(*) as count FROM installments WHERE installment_number = $installment_number AND user_id = $user_id AND id != $exclude_id")
                        else:
                            validation_queries.append("SELECT 'installment_number' as check_type, COUNT(*) as count FROM installments WHERE installment_number = $installment_number AND user_id = $user_id AND id != $exclude_id")
                        validation_params['$installment_number'] = new_installment_number
                        validation_params['$exclude_id'] = installment_id
                    
                    # Execute combined validation if needed
                    if validation_queries:
                        validation_params['$user_id'] = user_id
                        combined_validation_query = f"""
                        DECLARE $user_id AS Utf8;
                        {f'DECLARE $client_id AS Utf8;' if '$client_id' in validation_params else ''}
                        {f'DECLARE $installment_number AS Int32;' if '$installment_number' in validation_params else ''}
                        {f'DECLARE $exclude_id AS Utf8;' if '$exclude_id' in validation_params else ''}
                        {' '.join(validation_queries)};
                        """
                        
                        validation_rs = tx.execute(session.prepare(combined_validation_query), validation_params)
                        
                        if validation_rs[0].rows:
                            for row in validation_rs[0].rows:
                                check_type = getattr(row, 'check_type', '')
                                count = getattr(row, 'count', 0)
                                
                                if check_type == 'client' and count == 0:
                                    tx.rollback()
                                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Client not found'})}
                                elif check_type == 'installment_number' and count > 0:
                                    tx.rollback()
                                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Installment number {new_installment_number} is already in use'})}
                    
                    # Normalize wallet IDs for comparison (convert empty strings and None to None)
                    old_wallet_normalized = old_wallet_id if old_wallet_id and str(old_wallet_id).strip() else None
                    final_wallet_normalized = final_wallet_id if final_wallet_id and str(final_wallet_id).strip() else None
                    
                    # Handle wallet changes first (before updating installment)
                    if old_wallet_normalized != final_wallet_normalized:
                        logger.info(f"UPDATE-INSTALLMENT: wallet change from {old_wallet_normalized} to {final_wallet_normalized}")
                        
                        # Remove from old wallet if it existed
                        if old_wallet_normalized is not None:
                            logger.info(f"UPDATE-INSTALLMENT: removing from old wallet {old_wallet_normalized}")
                            
                            # Get paid amount for this installment
                            paid_sum_rs = tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $installment_id AS Utf8;
                                    SELECT COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
                                    FROM installment_payments WHERE installment_id = $installment_id;
                                    """
                                ),
                                {'$installment_id': installment_id}
                            )
                            paid_sum_dec = Decimal(str(paid_sum_rs[0].rows[0].paid_sum or 0)) if paid_sum_rs[0].rows else Decimal('0')
                            paid_sum_mu = int((paid_sum_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                            
                            # Get active allocations for this installment
                            alloc_rs = tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
                                    SELECT id, amount_minor_units
                                    FROM installment_allocations
                                    WHERE installment_id = $installment_id AND user_id = $user_id AND status = 'active';
                                    """
                                ),
                                {'$installment_id': installment_id, '$user_id': user_id}
                            )
                            allocations = list(alloc_rs[0].rows)
                            alloc_total_mu = sum(int(getattr(a, 'amount_minor_units', 0) or 0) for a in allocations)
                            
                            # Get current wallet balance/version
                            wb_rs = tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                                    SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                                    """
                                ),
                                {'$wallet_id': old_wallet_normalized, '$user_id': user_id}
                            )
                            if wb_rs[0].rows:
                                current_balance = int(wb_rs[0].rows[0].balance_minor_units or 0)
                                current_version = int(wb_rs[0].rows[0].version or 0)
                                
                                # Ledger: credit back allocations; debit reverse paid sums
                                if allocations:
                                    for a in allocations:
                                        tx.execute(
                                            session.prepare(
                                                """
                                                DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                                                INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                                                VALUES ($id, $wallet_id, $user_id, 'credit', $amt, CAST('RUB' AS Utf8), CAST('reversal' AS Utf8), $ref, $desc, $user_id, $ts);
                                                """
                                            ),
                                            {'$id': str(uuid.uuid4()), '$wallet_id': old_wallet_normalized, '$user_id': user_id, '$amt': int(getattr(a, 'amount_minor_units', 0) or 0), '$ref': getattr(a, 'id', ''), '$ts': now, '$desc': f'Reversal allocation for wallet change {installment_id}'}
                                        )
                                if paid_sum_mu > 0:
                                    tx.execute(
                                        session.prepare(
                                            """
                                            DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                                            INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                                            VALUES ($id, $wallet_id, $user_id, 'debit', $amt, CAST('RUB' AS Utf8), CAST('reversal' AS Utf8), $ref, $desc, $user_id, $ts);
                                            """
                                        ),
                                        {'$id': str(uuid.uuid4()), '$wallet_id': old_wallet_normalized, '$user_id': user_id, '$amt': paid_sum_mu, '$ref': installment_id, '$ts': now, '$desc': f'Reverse payments for wallet change {installment_id}'}
                                    )
                                
                                # Void allocations
                                if allocations:
                                    tx.execute(
                                        session.prepare(
                                            """
                                            DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
                                            UPDATE installment_allocations SET status = 'void'
                                            WHERE installment_id = $installment_id AND user_id = $user_id AND status = 'active';
                                            """
                                        ),
                                        {'$installment_id': installment_id, '$user_id': user_id}
                                    )
                                
                                # Update old wallet balance (credit back allocations, debit back payments)
                                new_balance = current_balance + alloc_total_mu - paid_sum_mu
                                
                                # Recompute aggregates for old wallet (excluding this installment)
                                _update_wallet_aggregates(session, tx, old_wallet_normalized, user_id, installment_id, current_version, new_balance, now)
                                
                                logger.info(f"UPDATE-INSTALLMENT: old wallet {old_wallet_normalized} updated")
                        
                        # Add to new wallet if specified
                        if final_wallet_normalized is not None:
                            logger.info(f"UPDATE-INSTALLMENT: adding to new wallet {final_wallet_normalized}")
                            
                            # Validate new wallet exists and is active
                            wallet_q = session.prepare(
                                """
                                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                                SELECT type FROM wallets WHERE id = $wallet_id AND user_id = $user_id AND status = 'active';
                                """
                            )
                            w_rs = tx.execute(wallet_q, {'$wallet_id': final_wallet_normalized, '$user_id': user_id})
                            if not (w_rs and len(w_rs) > 0 and w_rs[0].rows):
                                logger.error(f"UPDATE-INSTALLMENT: New wallet {final_wallet_normalized} not found or inactive")
                                tx.rollback()
                                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'New wallet not found or inactive'})}
                            
                            # Get new wallet balance/version
                            wb_rs = tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                                    SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                                    """
                                ),
                                {'$wallet_id': final_wallet_normalized, '$user_id': user_id}
                            )
                            if not (wb_rs and len(wb_rs) > 0 and wb_rs[0].rows):
                                tx.rollback()
                                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'New wallet balance not initialized'})}
                            current_balance = int(wb_rs[0].rows[0].balance_minor_units or 0)
                            current_version = int(wb_rs[0].rows[0].version or 0)
                            
                            # Use cash price for allocation
                            cash_price_mu = int((cash_price * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                            
                            # Create allocation record (active)
                            alloc_id = str(uuid.uuid4())
                            tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $id AS Utf8; DECLARE $installment_id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amount AS Int64; DECLARE $created_at AS Timestamp;
                                    INSERT INTO installment_allocations (id, installment_id, wallet_id, user_id, amount_minor_units, transaction_id, status, created_at)
                                    VALUES ($id, $installment_id, $wallet_id, $user_id, $amount, NULL, 'active', $created_at);
                                    """
                                ),
                                {'$id': alloc_id, '$installment_id': installment_id, '$wallet_id': final_wallet_normalized, '$user_id': user_id, '$amount': cash_price_mu, '$created_at': now}
                            )
                            
                            # Ledger debit for cash purchase
                            debit_id = str(uuid.uuid4())
                            tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                                    INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                                    VALUES ($id, $wallet_id, $user_id, 'debit', $amt, CAST('RUB' AS Utf8), CAST('installment' AS Utf8), $ref, $desc, $user_id, $ts);
                                    """
                                ),
                                {'$id': debit_id, '$wallet_id': final_wallet_normalized, '$user_id': user_id, '$amt': cash_price_mu, '$ref': installment_id, '$ts': now, '$desc': 'Installment cash purchase (wallet change)'}
                            )
                            
                            new_balance = current_balance - cash_price_mu
                            
                            # Get paid amount for this installment and add credit if any
                            paid_sum_rs = tx.execute(
                                session.prepare(
                                    """
                                    DECLARE $installment_id AS Utf8;
                                    SELECT COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
                                    FROM installment_payments WHERE installment_id = $installment_id;
                                    """
                                ),
                                {'$installment_id': installment_id}
                            )
                            paid_sum_dec = Decimal(str(paid_sum_rs[0].rows[0].paid_sum or 0)) if paid_sum_rs[0].rows else Decimal('0')
                            paid_sum_mu = int((paid_sum_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                            
                            if paid_sum_mu > 0:
                                # Ledger credit for existing payments
                                credit_id = str(uuid.uuid4())
                                tx.execute(
                                    session.prepare(
                                        """
                                        DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amt AS Int64; DECLARE $ref AS Utf8; DECLARE $ts AS Timestamp; DECLARE $desc AS Utf8;
                                        INSERT INTO ledger_transactions (id, wallet_id, user_id, direction, amount_minor_units, currency, reference_type, reference_id, description, created_by, created_at)
                                        VALUES ($id, $wallet_id, $user_id, 'credit', $amt, CAST('RUB' AS Utf8), CAST('installment' AS Utf8), $ref, $desc, $user_id, $ts);
                                        """
                                    ),
                                    {'$id': credit_id, '$wallet_id': final_wallet_normalized, '$user_id': user_id, '$amt': paid_sum_mu, '$ref': installment_id, '$ts': now, '$desc': 'Existing payments (wallet change)'}
                                )
                                new_balance += paid_sum_mu
                            
                            # Update new wallet balance and aggregates
                            _update_wallet_aggregates(session, tx, final_wallet_normalized, user_id, None, current_version, new_balance, now)
                            
                            logger.info(f"UPDATE-INSTALLMENT: new wallet {final_wallet_normalized} updated")
                    
                    # Update installment with allowed fields
                    update_query = """
                    DECLARE $installment_id AS Utf8;
                    DECLARE $client_id AS Utf8;
                    DECLARE $wallet_id AS Utf8?;
                    DECLARE $installment_number AS Int32;
                    DECLARE $product_name AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    
                    UPDATE installments 
                    SET client_id = $client_id,
                        wallet_id = $wallet_id,
                        installment_number = $installment_number,
                        product_name = $product_name,
                        updated_at = $updated_at
                    WHERE id = $installment_id;
                    """
                    
                    tx.execute(
                        session.prepare(update_query),
                        {
                            '$installment_id': installment_id,
                            '$client_id': final_client_id,
                            '$wallet_id': final_wallet_normalized,
                            '$installment_number': final_installment_number,
                            '$product_name': final_product_name,
                            '$updated_at': now
                        }
                    )
                    
                    # If we changed to a new wallet, we need to update the aggregates again with the correct installment price
                    if final_wallet_normalized is not None and old_wallet_normalized != final_wallet_normalized:
                        # Re-fetch wallet balance for final update with correct installment price
                        wb_rs = tx.execute(
                            session.prepare(
                                """
                                DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                                SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                                """
                            ),
                            {'$wallet_id': final_wallet_normalized, '$user_id': user_id}
                        )
                        if wb_rs[0].rows:
                            current_balance = int(wb_rs[0].rows[0].balance_minor_units or 0)
                            current_version = int(wb_rs[0].rows[0].version or 0)
                            
                            # Final update to wallet aggregates with correct installment price
                            _update_wallet_aggregates(session, tx, final_wallet_normalized, user_id, None, current_version, current_balance, now)
                    
                    tx.commit()
                    
                    # Log summary of changes
                    changes_made = []
                    if old_client_id != final_client_id:
                        changes_made.append(f"client: {old_client_id} → {final_client_id}")
                    if old_wallet_normalized != final_wallet_normalized:
                        changes_made.append(f"wallet: {old_wallet_normalized} → {final_wallet_normalized}")
                    if old_installment_number != final_installment_number:
                        changes_made.append(f"number: {old_installment_number} → {final_installment_number}")
                    if old_product_name != final_product_name:
                        changes_made.append(f"product: {old_product_name} → {final_product_name}")
                    
                    logger.info(f"UPDATE-INSTALLMENT: ✅ SUCCESS - installment {installment_id} updated: {', '.join(changes_made) if changes_made else 'no changes'}")
                    
                    return {
                        'statusCode': 200, 
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*',
                            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                        }, 
                        'body': json.dumps({
                            'message': 'Installment updated successfully',
                            'changes': {
                                'client_changed': old_client_id != final_client_id,
                                'wallet_changed': old_wallet_normalized != final_wallet_normalized,
                                'number_changed': old_installment_number != final_installment_number,
                                'product_changed': old_product_name != final_product_name,
                                'old_client_id': old_client_id,
                                'new_client_id': final_client_id,
                                'old_wallet': old_wallet_normalized,
                                'new_wallet': final_wallet_normalized,
                                'old_number': old_installment_number,
                                'new_number': final_installment_number,
                                'old_product': old_product_name,
                                'new_product': final_product_name
                            }
                        })
                    }
                    
                except Exception as e:
                    logger.error(f"UPDATE-INSTALLMENT: Error in transaction: {str(e)}")
                    try:
                        tx.rollback()
                    except:
                        pass
                    raise e

            return pool.retry_operation_sync(update_installment_in_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})}