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
    Void an installment allocation
    POST /installments/{installment_id}/allocations/{allocation_id}/void
    """
    try:
        # Parse request
        installment_id = event['pathParameters']['installment_id']
        allocation_id = event['pathParameters']['allocation_id']
        user_id = event['requestContext']['authorizer']['user_id']
        
        # Void allocation
        result = void_installment_allocation(installment_id, allocation_id, user_id)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        logger.error(f"Error voiding allocation: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def void_installment_allocation(installment_id, allocation_id, user_id):
    """Void an installment allocation and reverse the transaction"""
    driver = get_ydb_driver()
    
    try:
        with ydb.SessionPool(driver) as pool:
            def callee(session):
                # Start transaction
                tx = session.transaction(ydb.SerializableReadWrite())
                
                try:
                    # Get allocation to void
                    alloc_query = """
                    SELECT id, wallet_id, amount_minor_units, status
                    FROM installment_allocations
                    WHERE id = $allocation_id AND installment_id = $installment_id AND user_id = $user_id
                    """
                    alloc_result = tx.execute(alloc_query, {
                        '$allocation_id': allocation_id,
                        '$installment_id': installment_id,
                        '$user_id': user_id
                    })
                    
                    alloc_rows = list(alloc_result[0].rows)
                    if not alloc_rows:
                        raise ValueError("Allocation not found")
                    
                    allocation = alloc_rows[0]
                    if allocation.status != 'active':
                        raise ValueError("Allocation is not active and cannot be voided")

                    # Get wallet balance for update
                    wallet_query = """
                    SELECT version FROM wallet_balances
                    WHERE wallet_id = $wallet_id AND user_id = $user_id
                    """
                    wallet_result = tx.execute(wallet_query, {
                        '$wallet_id': allocation.wallet_id,
                        '$user_id': user_id
                    })
                    wallet_rows = list(wallet_result[0].rows)
                    if not wallet_rows:
                        raise ValueError("Wallet balance not found for the allocation wallet")
                    wallet_version = wallet_rows[0].version

                    now_iso = datetime.utcnow().isoformat()

                    # Update allocation status to void
                    update_alloc_query = """
                    UPDATE installment_allocations SET status = 'void'
                    WHERE id = $allocation_id AND user_id = $user_id
                    """
                    tx.execute(update_alloc_query, {'$allocation_id': allocation_id, '$user_id': user_id})
                    
                    # Create credit transaction (reversal)
                    reversal_txn_id = str(uuid.uuid4())
                    reversal_query = """
                    INSERT INTO ledger_transactions (
                        id, wallet_id, user_id, direction, amount_minor_units, currency,
                        reference_type, reference_id, description, created_by, created_at
                    ) VALUES (
                        $id, $wallet_id, $user_id, 'credit', $amount, CAST('RUB' AS Utf8),
                        CAST('reversal' AS Utf8), $ref_id, $desc, $user_id, $now
                    )
                    """
                    base_desc = f"Reversal for allocation {allocation_id}"
                    tx.execute(reversal_query, {
                        '$id': reversal_txn_id,
                        '$wallet_id': allocation.wallet_id,
                        '$user_id': user_id,
                        '$amount': allocation.amount_minor_units,
                        '$ref_id': allocation_id,
                        '$desc': base_desc,
                        '$now': now_iso
                    })
                    
                    # Recompute aggregates for wallet after voiding
                    # total_allocated = sum remaining across linked installments
                    total_alloc_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(rem), CAST(0 AS Decimal(22,9))) AS total_remaining
                        FROM (
                          SELECT i.id,
                            CAST(i.installment_price AS Decimal(22,9)) - CAST(COALESCE(p.paid_sum, CAST(0 AS Decimal(22,9))) AS Decimal(22,9)) AS rem
                          FROM installments i LEFT JOIN (
                            SELECT installment_id, COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
                            FROM installment_payments GROUP BY installment_id
                          ) AS p ON p.installment_id = i.id
                          WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id
                        );
                        """,
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal, ROUND_HALF_UP
                    total_remaining_dec = Decimal(str(total_alloc_rs[0].rows[0].total_remaining or 0)) if total_alloc_rs[0].rows else Decimal('0')
                    total_alloc_mu = int((total_remaining_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    # due_to_get = sum of the next unpaid payment per installment
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
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal, ROUND_HALF_UP
                    due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0)) if nd_rs[0].rows else Decimal('0')
                    due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    # Fetch wallet investor fields
                    w_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT type, investment_amount_minor_units, investor_percentage
                        FROM wallets WHERE id = $wallet_id AND user_id = $user_id;
                        """,
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    wallet_type = str(w_rs[0].rows[0].type or '').lower() if w_rs[0].rows else ''
                    investment_amount_mu = int(w_rs[0].rows[0].investment_amount_minor_units or 0) if w_rs[0].rows else 0
                    investor_pct = Decimal(str(w_rs[0].rows[0].investor_percentage or 0)) if w_rs[0].rows else Decimal('0')

                    # Compute new balance and expected_revenue
                    new_balance = None
                    # fetch current balance in case we need it
                    bal_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT balance_minor_units FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                        """,
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    if bal_rs[0].rows:
                        new_balance = int(bal_rs[0].rows[0].balance_minor_units or 0) + int(allocation.amount_minor_units)
                    else:
                        new_balance = int(allocation.amount_minor_units)

                    exp_rev_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """,
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    profit_sum = Decimal(str(exp_rev_rs[0].rows[0].profit_sum or 0)) if exp_rev_rs[0].rows else Decimal('0')
                    expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                    # Update wallet balance (credit back) and aggregates with version check
                    balance_update_query = """
                    UPDATE wallet_balances 
                    SET balance_minor_units = balance_minor_units + $amount, 
                        version = version + 1,
                        updated_at = $now,
                        total_allocated_minor_units = $total_alloc,
                        due_to_get_minor_units = $due_to_get,
                        expected_revenue_minor_units = $exp_rev,
                        spent_on_products_minor_units = $spent_mu
                    WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $version
                    """
                    # Spent on products = sum of cash_price
                    spent_rs = tx.execute(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id;
                        """,
                        {'$wallet_id': allocation.wallet_id, '$user_id': user_id}
                    )
                    from decimal import Decimal as _D, ROUND_HALF_UP as RHU
                    spent_sum_dec = _D(str(spent_rs[0].rows[0].spent_sum or 0)) if spent_rs[0].rows else _D('0')
                    spent_mu = int((spent_sum_dec * _D('100')).quantize(_D('1'), rounding=RHU))

                    result = tx.execute(balance_update_query, {
                        '$amount': allocation.amount_minor_units,
                        '$now': now_iso,
                        '$wallet_id': allocation.wallet_id,
                        '$user_id': user_id,
                        '$version': wallet_version,
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

                    tx.commit()
                    
                    return {'status': 'voided', 'allocation_id': allocation_id}
                    
                except Exception as e:
                    tx.rollback()
                    raise e
            
            return pool.retry_operation_sync(callee)
            
    finally:
        driver.stop()
