import json
import os
import logging
from datetime import datetime
import uuid
import ydb
from jwt_auth import jwt_required

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


# Database configuration
YDB_ENDPOINT = os.environ.get('YDB_ENDPOINT')
YDB_DATABASE = os.environ.get('YDB_DATABASE')

def get_ydb_driver():
    """Create YDB driver instance"""
    return ydb.Driver(
        endpoint=YDB_ENDPOINT,
        database=YDB_DATABASE,
        credentials=ydb.credentials_from_env_variables()
    )

@jwt_required
def handler(event, context):
    """
    Allocate funds from a wallet to an installment
    POST /installments/{installment_id}/allocate
    """
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        # Parse request
        installment_id = event['pathParameters']['installment_id']
        body = json.loads(event['body'])
        
        wallet_id = body.get('wallet_id')
        amount_minor_units = body.get('amount_minor_units')
        notes = body.get('notes', '')
        
        # Validate required fields
        if not wallet_id or not amount_minor_units:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'wallet_id and amount_minor_units are required'
                })
            }
        
        # Validate amount
        if amount_minor_units <= 0:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'amount_minor_units must be positive'
                })
            }
        
        # Get user ID from JWT
        user_id = event['requestContext']['authorizer']['user_id']
        
        # Create allocation
        allocation = create_installment_allocation(
            installment_id, wallet_id, amount_minor_units, notes, user_id
        )
        
        return {
            'statusCode': 201,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(allocation)
        }
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        logger.error(f"Error allocating installment: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def create_installment_allocation(installment_id, wallet_id, amount_minor_units, notes, user_id):
    """Create installment allocation with transaction"""
    driver = get_ydb_driver()
    
    try:
        with ydb.SessionPool(driver) as pool:
            def callee(session):
                # Start transaction
                tx = session.transaction(ydb.SerializableReadWrite())
                
                try:
                    # Check if installment exists and get details
                    installment_query = """
                    SELECT id, client_id, installment_price, status, installment_number
                    FROM installments 
                    WHERE id = $installment_id AND user_id = $user_id
                    """
                    
                    installment_result = tx.execute(
                        installment_query,
                        {'$installment_id': installment_id, '$user_id': user_id}
                    )
                    
                    installment_rows = list(installment_result[0].rows)
                    if not installment_rows:
                        raise ValueError("Installment not found")
                    
                    installment = installment_rows[0]
                    if installment.status == 'cancelled':
                        raise ValueError("Cannot allocate to cancelled installment")
                    
                    # Check if wallet exists and has sufficient balance
                    wallet_query = """
                    SELECT w.id, w.type, wb.balance_minor_units, wb.version
                    FROM wallets w
                    JOIN wallet_balances wb ON w.id = wb.wallet_id AND w.user_id = wb.user_id
                    WHERE w.id = $wallet_id AND w.user_id = $user_id AND w.status = 'active'
                    """
                    
                    wallet_result = tx.execute(
                        wallet_query,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    
                    wallet_rows = list(wallet_result[0].rows)
                    if not wallet_rows:
                        raise ValueError("Wallet not found or inactive")
                    
                    wallet = wallet_rows[0]
                    if wallet.balance_minor_units < amount_minor_units:
                        raise ValueError("Insufficient wallet balance")
                    
                    # Check existing allocations to prevent over-allocation
                    existing_allocations_query = """
                    SELECT COALESCE(SUM(amount_minor_units), 0) as total_allocated
                    FROM installment_allocations
                    WHERE installment_id = $installment_id AND user_id = $user_id AND status = 'active'
                    """
                    
                    existing_result = tx.execute(
                        existing_allocations_query,
                        {'$installment_id': installment_id, '$user_id': user_id}
                    )
                    
                    total_allocated = list(existing_result[0].rows)[0].total_allocated
                    # Installment cap in minor units (RUB cents)
                    from decimal import Decimal, ROUND_HALF_UP
                    installment_price_mu = int((Decimal(str(installment.installment_price)) * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
                    remaining_amount = installment_price_mu - total_allocated
                    
                    if amount_minor_units > remaining_amount:
                        raise ValueError(f"Allocation amount exceeds remaining installment amount. Remaining: {remaining_amount} minor units")
                    
                    # Generate IDs
                    allocation_id = str(uuid.uuid4())
                    transaction_id = str(uuid.uuid4())
                    now_iso = datetime.utcnow().isoformat()

                    # If installment is not yet linked to a wallet, set it now
                    link_wallet_query = """
                    UPDATE installments SET wallet_id = $wallet_id
                    WHERE id = $installment_id AND user_id = $user_id AND (wallet_id IS NULL OR wallet_id = '' );
                    """
                    tx.execute(link_wallet_query, {
                        '$installment_id': installment_id,
                        '$wallet_id': wallet_id,
                        '$user_id': user_id
                    })

                    # Create allocation record
                    allocation_query = """
                    INSERT INTO installment_allocations (
                        id, installment_id, wallet_id, user_id, amount_minor_units, 
                        transaction_id, status, created_at
                    ) VALUES (
                        $id, $installment_id, $wallet_id, $user_id, $amount_minor_units,
                        $transaction_id, 'active', $created_at
                    )
                    """
                    
                    tx.execute(allocation_query, {
                        '$id': allocation_id,
                        '$installment_id': installment_id,
                        '$wallet_id': wallet_id,
                        '$user_id': user_id,
                        '$amount_minor_units': amount_minor_units,
                        '$transaction_id': transaction_id,
                        '$created_at': now_iso
                    })
                    
                    # Create debit transaction for wallet
                    transaction_query = """
                    INSERT INTO ledger_transactions (
                        id, wallet_id, user_id, direction, amount_minor_units, currency,
                        reference_type, reference_id, description, created_by, created_at
                    ) VALUES (
                        $id, $wallet_id, $user_id, 'debit', $amount_minor_units, CAST('RUB' AS Utf8),
                        CAST('installment' AS Utf8), $reference_id, $description, $created_by, $created_at
                    )
                    """
                    
                    description = f"Installment allocation: {notes}" if notes else f"Allocation for installment {installment_id}"
                    tx.execute(transaction_query, {
                        '$id': transaction_id,
                        '$wallet_id': wallet_id,
                        '$user_id': user_id,
                        '$amount_minor_units': amount_minor_units,
                        '$reference_id': installment_id,
                        '$description': description,
                        '$created_by': user_id,
                        '$created_at': now_iso
                    })
                    
                    # Recompute wallet aggregates: total installment volume, due_to_get, expected_revenue
                    total_alloc_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS total_allocated
                        FROM installments i
                        WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal, ROUND_HALF_UP
                    total_allocated_dec = Decimal(str(total_alloc_rs[0].rows[0].total_allocated or 0)) if total_alloc_rs[0].rows else Decimal('0')
                    total_alloc_mu = int((total_allocated_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    # due_to_get = sum of next unpaid payment per installment
                    nd_rs = tx.execute(
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
                        """,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal, ROUND_HALF_UP
                    due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0)) if nd_rs[0].rows else Decimal('0')
                    due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    # Fetch wallet investor fields for expected_revenue
                    w_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT type, investment_amount_minor_units, investor_percentage
                        FROM wallets WHERE id = $wallet_id AND user_id = $user_id;
                        """,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    wallet_type = str(w_rs[0].rows[0].type or '').lower() if w_rs[0].rows else ''
                    investment_amount_mu = int(w_rs[0].rows[0].investment_amount_minor_units or 0) if w_rs[0].rows else 0
                    investor_pct = Decimal(str(w_rs[0].rows[0].investor_percentage or 0)) if w_rs[0].rows else Decimal('0')

                    # Update wallet balance and aggregates atomically with version check
                    new_balance = wallet.balance_minor_units - amount_minor_units
                    new_version = wallet.version + 1
                    exp_rev_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    profit_sum = Decimal(str(exp_rev_rs[0].rows[0].profit_sum or 0)) if exp_rev_rs[0].rows else Decimal('0')
                    expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    balance_update_query = """
                    UPDATE wallet_balances 
                    SET balance_minor_units = $new_balance, 
                        version = $new_version,
                        updated_at = $updated_at,
                        total_allocated_minor_units = $total_alloc,
                        due_to_get_minor_units = $due_to_get,
                    expected_revenue_minor_units = $exp_rev,
                    spent_on_products_minor_units = $spent_mu
                    WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $current_version
                    """
                    
                    # spent = sum of cash_price
                    spent_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """,
                        {'$wallet_id': wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal as _D, ROUND_HALF_UP as RHU
                    spent_sum_dec = _D(str(spent_rs[0].rows[0].spent_sum or 0)) if spent_rs[0].rows else _D('0')
                    spent_mu = int((spent_sum_dec * _D('100')).quantize(_D('1'), rounding=RHU))

                    result = tx.execute(balance_update_query, {
                        '$new_balance': new_balance,
                        '$new_version': new_version,
                        '$updated_at': now_iso,
                        '$wallet_id': wallet_id,
                        '$user_id': user_id,
                        '$current_version': wallet.version,
                        '$total_alloc': total_alloc_mu,
                        '$due_to_get': due_to_get_mu,
                        '$exp_rev': expected_revenue_mu,
                        '$spent_mu': spent_mu
                    })
                    ra = None
                    try:
                        ra = getattr(getattr(result[0], 'stats', None), 'rows_affected', None)
                    except Exception:
                        ra = None
                    if ra is not None and ra == 0:
                        raise ydb.Aborted("Concurrent update to wallet balance detected.")

                    # Commit transaction
                    tx.commit()
                    
                    return {
                        'id': allocation_id,
                        'installment_id': installment_id,
                        'wallet_id': wallet_id,
                        'amount_minor_units': amount_minor_units,
                        'status': 'active',
                        'created_at': now_iso
                    }
                    
                except Exception as e:
                    tx.rollback()
                    raise e
            
            return pool.retry_operation_sync(callee)
            
    finally:
        driver.stop()
