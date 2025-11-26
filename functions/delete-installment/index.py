import json
import os
import ydb
import jwt
import logging
import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Union, Optional, Tuple

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
        logger.info(f"Received delete request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        # Get installment ID from path parameters
        installment_id = event['pathParameters']['id']
        
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
            tx = session.transaction(ydb.SerializableReadWrite())

            # Verify and fetch installment
            inst_q = session.prepare(
                """
                DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
                SELECT id, wallet_id FROM installments WHERE id = $installment_id AND user_id = $user_id;
                """
            )
            inst_rs = tx.execute(inst_q, {'$installment_id': installment_id, '$user_id': user_id})
            if not inst_rs[0].rows:
                raise Exception("Installment not found or access denied")
            wallet_id = getattr(inst_rs[0].rows[0], 'wallet_id', None)

            # Sum paid across payments (to reverse from wallet if any)
            sum_paid_rs = tx.execute(
                session.prepare(
                    """
                    DECLARE $installment_id AS Utf8;
                    SELECT COALESCE(SUM(paid_amount), CAST(0 AS Decimal(22,9))) AS paid_sum
                    FROM installment_payments WHERE installment_id = $installment_id;
                    """
                ),
                {'$installment_id': installment_id}
            )
            paid_sum_dec = Decimal(str(sum_paid_rs[0].rows[0].paid_sum or 0)) if sum_paid_rs[0].rows else Decimal('0')
            paid_sum_mu = int((paid_sum_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

            if wallet_id is not None and str(wallet_id).strip() != '':
                # Fetch active allocations for this installment
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

                # Current wallet balance/version
                wb_rs = tx.execute(
                    session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                        SELECT balance_minor_units, version FROM wallet_balances WHERE wallet_id = $wallet_id AND user_id = $user_id;
                        """
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id}
                )
                current_balance = int(wb_rs[0].rows[0].balance_minor_units or 0) if wb_rs[0].rows else 0
                current_version = int(wb_rs[0].rows[0].version or 0) if wb_rs[0].rows else 0

                # Aggregates across remaining installments (exclude this one)
                total_alloc_rs = tx.execute(
                    session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $exclude_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS total_allocated
                        FROM installments i
                        WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id AND i.id != $exclude_id;
                        """
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': installment_id}
                )
                total_allocated_dec = Decimal(str(total_alloc_rs[0].rows[0].total_allocated or 0)) if total_alloc_rs[0].rows else Decimal('0')
                total_alloc_mu = int((total_allocated_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                nd_rs = tx.execute(
                    session.prepare(
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
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': installment_id}
                )
                due_next_dec = Decimal(str(nd_rs[0].rows[0].due_next_sum or 0)) if nd_rs[0].rows else Decimal('0')
                due_to_get_mu = int((due_next_dec * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                exp_rev_rs = tx.execute(
                    session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $exclude_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.installment_price AS Decimal(22,9)) - CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS profit_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id AND i.id != $exclude_id;
                        """
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': installment_id}
                )
                profit_sum = Decimal(str(exp_rev_rs[0].rows[0].profit_sum or 0)) if exp_rev_rs[0].rows else Decimal('0')
                expected_revenue_mu = int((profit_sum * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

                # Ledger: credit back allocations; debit reverse paid sums
                if allocations:
                    for a in allocations:
                        tx.execute(
                            session.prepare(
                                """
                                DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amount AS Int64; DECLARE $ref AS Utf8; DECLARE $now AS Timestamp; DECLARE $desc AS Utf8;
                                INSERT INTO ledger_transactions (
                                  id, wallet_id, user_id, direction, amount_minor_units, currency,
                                  reference_type, reference_id, description, created_by, created_at
                                ) VALUES (
                                  $id, $wallet_id, $user_id, 'credit', $amount, CAST('RUB' AS Utf8),
                                  CAST('reversal' AS Utf8), $ref, $desc, $user_id, $now
                                );
                                """
                            ),
                            {'$id': str(uuid.uuid4()), '$wallet_id': wallet_id, '$user_id': user_id, '$amount': int(getattr(a, 'amount_minor_units', 0) or 0), '$ref': getattr(a, 'id', ''), '$desc': f'Reversal allocation for deleted installment {installment_id}', '$now': datetime.utcnow()}
                        )
                if paid_sum_mu > 0:
                    tx.execute(
                        session.prepare(
                            """
                            DECLARE $id AS Utf8; DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $amount AS Int64; DECLARE $ref AS Utf8; DECLARE $now AS Timestamp; DECLARE $desc AS Utf8;
                            INSERT INTO ledger_transactions (
                              id, wallet_id, user_id, direction, amount_minor_units, currency,
                              reference_type, reference_id, description, created_by, created_at
                            ) VALUES (
                              $id, $wallet_id, $user_id, 'debit', $amount, CAST('RUB' AS Utf8),
                              CAST('reversal' AS Utf8), $ref, $desc, $user_id, $now
                            );
                            """
                        ),
                        {'$id': str(uuid.uuid4()), '$wallet_id': wallet_id, '$user_id': user_id, '$amount': paid_sum_mu, '$ref': installment_id, '$desc': f'Reverse payments for deleted installment {installment_id}', '$now': datetime.utcnow()}
                    )

                # Update wallet balance and aggregates
                new_balance = current_balance + alloc_total_mu - paid_sum_mu
                wb_update_q = session.prepare(
                    """
                    DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8;
                    DECLARE $new_balance AS Int64; DECLARE $new_version AS Uint64;
                    DECLARE $total_alloc AS Int64; DECLARE $due_to_get AS Int64; DECLARE $exp_rev AS Int64; DECLARE $paid_mu AS Int64; DECLARE $spent_mu AS Int64;
                    DECLARE $curr_version AS Uint64; DECLARE $now AS Timestamp;
                    UPDATE wallet_balances
                    SET balance_minor_units = $new_balance,
                        version = $new_version,
                        updated_at = $now,
                        total_allocated_minor_units = $total_alloc,
                        due_to_get_minor_units = $due_to_get,
                        expected_revenue_minor_units = $exp_rev,
                        spent_on_products_minor_units = $spent_mu,
                        paid_amount_minor_units = COALESCE(paid_amount_minor_units, 0) - $paid_mu
                    WHERE wallet_id = $wallet_id AND user_id = $user_id AND COALESCE(version, CAST(0 AS Uint64)) = $curr_version;
                    """
                )
                # Spent on products = sum of cash_price (excluding the installment being deleted)
                spent_rs = tx.execute(
                    session.prepare(
                        """
                        DECLARE $wallet_id AS Utf8; DECLARE $user_id AS Utf8; DECLARE $exclude_id AS Utf8;
                        SELECT COALESCE(SUM(CAST(i.cash_price AS Decimal(22,9))), CAST(0 AS Decimal(22,9))) AS spent_sum
                        FROM installments i WHERE i.wallet_id = $wallet_id AND i.user_id = $user_id AND i.id != $exclude_id;
                        """
                    ),
                    {'$wallet_id': wallet_id, '$user_id': user_id, '$exclude_id': installment_id}
                )
                from decimal import Decimal as _D, ROUND_HALF_UP as RHU
                spent_sum_dec = _D(str(spent_rs[0].rows[0].spent_sum or 0)) if spent_rs[0].rows else _D('0')
                spent_mu = int((spent_sum_dec * _D('100')).quantize(_D('1'), rounding=RHU))

                tx.execute(wb_update_q, {
                    '$wallet_id': wallet_id,
                    '$user_id': user_id,
                    '$new_balance': new_balance,
                    '$new_version': int(current_version) + 1,
                    '$total_alloc': total_alloc_mu,
                    '$due_to_get': due_to_get_mu,
                    '$exp_rev': expected_revenue_mu,
                    '$spent_mu': spent_mu,
                    '$paid_mu': paid_sum_mu,
                    '$curr_version': int(current_version),
                    '$now': datetime.utcnow()
                })

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

            # Delete child payments then the installment
            tx.execute(session.prepare("""
                DECLARE $installment_id AS Utf8;
                DELETE FROM installment_payments WHERE installment_id = $installment_id;
            """), {'$installment_id': installment_id})
            tx.execute(session.prepare("""
                DECLARE $installment_id AS Utf8; DECLARE $user_id AS Utf8;
                DELETE FROM installments WHERE id = $installment_id AND user_id = $user_id;
            """), {'$installment_id': installment_id, '$user_id': user_id})

            tx.commit()
        
        try:
            pool.retry_operation_sync(execute_query)
        finally:
            driver.stop()
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'message': 'Installment deleted successfully'})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            'body': json.dumps({'error': str(e)})
        } 
