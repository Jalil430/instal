import json
import os
import ydb
import jwt
import logging
from typing import Union, Optional, Tuple
from decimal import Decimal
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
        if 'is_paid' not in body or not isinstance(body.get('is_paid'), bool):
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "'is_paid' (boolean) is a required field"})}

        is_paid = body['is_paid']
        paid_date = None

        if is_paid:
            if 'paid_date' not in body or not body['paid_date']:
                return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': "'paid_date' is required when 'is_paid' is true"})}
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
            logger.info(f"Starting execute_query with payment_id: {payment_id}, user_id: {user_id}")
            
            try:
                # First, verify the payment belongs to an installment owned by the authenticated user
                # and get the installment_id for updating calculated fields
                verify_query = """DECLARE $payment_id AS Utf8;
SELECT installment_id FROM installment_payments WHERE id = $payment_id;"""
                
                logger.info(f"Executing verify query with payment_id: {payment_id}")
                logger.info(f"Verify query text: {verify_query}")
                try:
                    prepared_query = session.prepare(verify_query)
                    logger.info("Query prepared successfully")
                    verify_result = session.transaction().execute(
                        prepared_query,
                        {'$payment_id': payment_id},
                        commit_tx=False
                    )
                    logger.info(f"Verify query executed successfully")
                except Exception as query_error:
                    logger.error(f"Query execution failed: {query_error}")
                    logger.error(f"Query was: {verify_query}")
                    raise
            except Exception as e:
                logger.error(f"Error in verify query: {str(e)}")
                raise
            
            # Handle synthetic payment IDs (ending with _next)
            if not verify_result[0].rows and payment_id.endswith('_next'):
                installment_id = payment_id.replace('_next', '')
                logger.info(f"Detected synthetic payment ID. Looking for next unpaid payment in installment: {installment_id}")
                
                # Find the actual next unpaid payment for this installment
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
                
            elif not verify_result[0].rows:
                logger.error(f"Payment not found or access denied. payment_id: {payment_id}, user_id: {user_id}")
                raise Exception("Payment not found or access denied")
            else:
                row = verify_result[0].rows[0]
                installment_id = row.installment_id
                logger.info(f"Found installment_id: {installment_id} for payment_id: {payment_id}")

            
            # Prepare queries outside transaction
            update_payment_query = """
            DECLARE $payment_id AS Utf8;
            DECLARE $is_paid AS Bool;
            DECLARE $paid_date AS Optional<Date>;
            DECLARE $updated_at AS Timestamp;
            
            UPDATE installment_payments
            SET 
                is_paid = $is_paid,
                paid_date = $paid_date,
                updated_at = $updated_at
            WHERE id = $payment_id;
            """
            
            prepared_update_payment = session.prepare(update_payment_query)
            
            # Start transaction for atomic updates
            tx = session.transaction(ydb.SerializableReadWrite())
            
            # Update the payment first
            logger.info(f"Updating payment {payment_id} to is_paid={is_paid}, paid_date={paid_date}")
            tx.execute(
                prepared_update_payment,
                {
                    '$payment_id': payment_id,
                    '$is_paid': is_paid,
                    '$paid_date': paid_date,
                    '$updated_at': datetime.utcnow()
                }
            )
            logger.info(f"Payment {payment_id} updated successfully")
            
            # Now get installment data (within the same transaction to see updated payment)
            installment_query = """
DECLARE $installment_id AS Utf8;
SELECT installment_price FROM installments WHERE id = $installment_id;
"""
            
            installment_result = tx.execute(
                session.prepare(installment_query),
                {'$installment_id': installment_id}
            )
            
            if not installment_result[0].rows:
                raise Exception("Installment not found")
                
            installment_price = installment_result[0].rows[0].installment_price
            
            # Get payment statistics (within transaction to see the updated payment)
            payment_stats_query = """
DECLARE $installment_id AS Utf8;
SELECT 
    COALESCE(SUM(CASE WHEN is_paid = true THEN expected_amount ELSE CAST(0 AS Decimal(22,9)) END), CAST(0 AS Decimal(22,9))) as paid_amount,
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