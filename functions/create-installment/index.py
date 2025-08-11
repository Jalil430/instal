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
                
                # First, get client and investor names for calculated fields
                client_query = """
                DECLARE $client_id AS Utf8;
                SELECT full_name FROM clients WHERE id = $client_id;
                """
                client_result = tx.execute(session.prepare(client_query), {'$client_id': body['client_id']})
                client_name = client_result[0].rows[0].full_name if client_result[0].rows else 'Unknown Client'
                
                investor_query = """
                DECLARE $investor_id AS Utf8;
                SELECT full_name FROM investors WHERE id = $investor_id;
                """
                investor_result = tx.execute(session.prepare(investor_query), {'$investor_id': body['investor_id']})
                investor_name = investor_result[0].rows[0].full_name if investor_result[0].rows else 'Unknown Investor'
                
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
                    if max_result[0].rows and hasattr(max_result[0].rows[0], 'max_num') and max_result[0].rows[0].max_num is not None:
                        new_number = int(max_result[0].rows[0].max_num) + 1
                    else:
                        new_number = 1
                else:
                    new_number = manual_number

                query = """
                DECLARE $id AS Utf8;
                DECLARE $user_id AS Utf8;
                DECLARE $client_id AS Utf8;
                DECLARE $investor_id AS Utf8;
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
                DECLARE $investor_name AS Utf8;
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
                    investor_id,
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
                    investor_name,
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
                    $investor_id,
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
                    $investor_name,
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
                        '$investor_id': body['investor_id'],
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
                        '$investor_name': investor_name,
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