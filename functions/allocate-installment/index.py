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
    Allocate funds from a wallet to an installment
    POST /installments/{installment_id}/allocate
    """
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
                    SELECT id, client_id, total_amount_minor_units, status
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
                    remaining_amount = installment.total_amount_minor_units - total_allocated
                    
                    if amount_minor_units > remaining_amount:
                        raise ValueError(f"Allocation amount exceeds remaining installment amount. Remaining: {remaining_amount} minor units")
                    
                    # Generate IDs
                    allocation_id = str(uuid.uuid4())
                    transaction_id = str(uuid.uuid4())
                    now_iso = datetime.utcnow().isoformat()

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
                        $id, $wallet_id, $user_id, 'debit', $amount_minor_units, 'RUB',
                        'installment', $reference_id, $description, $created_by, $created_at
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
                    
                    # Update wallet balance
                    new_balance = wallet.balance_minor_units - amount_minor_units
                    new_version = wallet.version + 1
                    
                    balance_update_query = """
                    UPDATE wallet_balances 
                    SET balance_minor_units = $new_balance, 
                        version = $new_version,
                        updated_at = $updated_at
                    WHERE wallet_id = $wallet_id AND user_id = $user_id AND version = $current_version
                    """
                    
                    result = tx.execute(balance_update_query, {
                        '$new_balance': new_balance,
                        '$new_version': new_version,
                        '$updated_at': now_iso,
                        '$wallet_id': wallet_id,
                        '$user_id': user_id,
                        '$current_version': wallet.version
                    })

                    if result[0].stats.rows_affected == 0:
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