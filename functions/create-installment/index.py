import os
import json
import uuid
import ydb
import hmac
import logging
import calendar
from datetime import datetime, date
from decimal import Decimal

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ApiKeyAuth:
    """Handles API key authentication"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured")
            return False
        
        headers = event.get('headers', {})
        api_key = headers.get('x-api-key') or headers.get('X-Api-Key')
        if not api_key:
            logger.warning("No API key provided")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function handler to create a new installment.
    """
    try:
        logger.info(f"Received create request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
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
                DECLARE $created_at AS Timestamp;
                DECLARE $updated_at AS Timestamp;
                
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
                    created_at,
                    updated_at
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
                    $created_at,
                    $updated_at
                );
                """
                
                # Create a transaction
                tx = session.transaction(ydb.SerializableReadWrite())
                
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
                        '$installment_price': Decimal(str(body['installment_price'])),
                        '$down_payment': Decimal(str(body['down_payment'])),
                        '$term_months': int(body['term_months']),
                        '$down_payment_date': down_payment_date,
                        '$installment_start_date': installment_start_date,
                        '$installment_end_date': installment_end_date,
                        '$monthly_payment': Decimal(str(body['monthly_payment'])),
                        '$created_at': now,
                        '$updated_at': now
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