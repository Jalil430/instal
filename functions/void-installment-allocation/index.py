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
                        $id, $wallet_id, $user_id, 'credit', $amount, 'RUB',
                        'reversal', $ref_id, $desc, $user_id, $now
                    )
                    """
                    tx.execute(reversal_query, {
                        '$id': reversal_txn_id,
                        '$wallet_id': allocation.wallet_id,
                        '$user_id': user_id,
                        '$amount': allocation.amount_minor_units,
                        '$ref_id': allocation_id,
                        '$desc': f"Reversal for allocation {allocation_id}",
                        '$now': now_iso
                    })
                    
                    # Update wallet balance
                    balance_update_query = """
                    UPDATE wallet_balances 
                    SET balance_minor_units = balance_minor_units + $amount, 
                        version = version + 1,
                        updated_at = $now
                    WHERE wallet_id = $wallet_id AND user_id = $user_id AND version = $version
                    """
                    result = tx.execute(balance_update_query, {
                        '$amount': allocation.amount_minor_units,
                        '$now': now_iso,
                        '$wallet_id': allocation.wallet_id,
                        '$user_id': user_id,
                        '$version': wallet_version
                    })

                    if result[0].stats.rows_affected == 0:
                        raise ydb.Aborted("Concurrent update to wallet balance detected.")

                    tx.commit()
                    
                    return {'status': 'voided', 'allocation_id': allocation_id}
                    
                except Exception as e:
                    tx.rollback()
                    raise e
            
            return pool.retry_operation_sync(callee)
            
    finally:
        driver.stop()