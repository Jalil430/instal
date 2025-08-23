import json
import os
import logging
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
    Get all allocations for an installment
    GET /installments/{installment_id}/allocations
    """
    try:
        # Parse request
        installment_id = event['pathParameters']['installment_id']
        user_id = event['requestContext']['authorizer']['user_id']
        
        # Get allocations
        allocations = get_allocations(installment_id, user_id)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(allocations)
        }
        
    except Exception as e:
        logger.error(f"Error getting allocations: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_allocations(installment_id, user_id):
    """Get all allocations for a given installment"""
    driver = get_ydb_driver()
    
    with ydb.SessionPool(driver) as pool:
        def callee(session):
            query = """
            SELECT id, wallet_id, amount_minor_units, status, created_at
            FROM installment_allocations
            WHERE installment_id = $installment_id AND user_id = $user_id
            ORDER BY created_at DESC
            """
            
            result_sets = session.transaction(ydb.SerializableReadOnly()).execute(
                query,
                {
                    '$installment_id': installment_id,
                    '$user_id': user_id
                }
            )
            
            allocations = []
            for row in result_sets[0].rows:
                allocations.append({
                    'id': row.id.decode('utf-8'),
                    'wallet_id': row.wallet_id.decode('utf-8'),
                    'amount_minor_units': row.amount_minor_units,
                    'status': row.status.decode('utf-8'),
                    'created_at': row.created_at.isoformat()
                })
            
            return allocations
            
        return pool.retry_operation_sync(callee)
