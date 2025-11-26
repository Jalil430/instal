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
        # Handle CORS preflight requests
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                },
                'body': ''
            }
        
        logger.info(f"Received search request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401, 
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                }, 
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # Get search parameters from query string - enforce user_id from JWT
        query_params = event.get('queryStringParameters') or {}
        installment_number = query_params.get('installment_number')  # Installment number to search
        client_name = query_params.get('client_name')               # Client full name
        
        logger.info(f"Search parameters: installment_number='{installment_number}', client_name='{client_name}'")
        logger.info(f"User ID from JWT: {user_id}")
        
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
            # Validate input parameters
            if not installment_number or not client_name:
                raise ValueError("Both installment_number and client_name are required")
            
            try:
                installment_num = int(installment_number)
            except ValueError:
                raise ValueError("installment_number must be a valid integer")
            
            # Step 1: Find installment by installment_number and client_name to get client_id
            installment_search_query = """
            DECLARE $user_id AS Utf8;
            DECLARE $installment_number AS Int32;
            DECLARE $client_name AS Utf8;
            
            SELECT client_id, client_name, id as searched_installment_id
            FROM installments
            WHERE user_id = $user_id 
              AND installment_number = $installment_number
              AND client_name LIKE $client_name
            LIMIT 1;
            """
            
            search_params = {
                '$user_id': user_id,
                '$installment_number': installment_num,
                '$client_name': f"%{client_name}%"
            }
            
            prepared_search_query = session.prepare(installment_search_query)
            search_result_sets = session.transaction().execute(
                prepared_search_query,
                search_params,
                commit_tx=True
            )
            
            # Check if installment found
            search_rows = list(search_result_sets[0].rows)
            if not search_rows:
                return []  # No installment found, return empty list
            
            search_row = search_rows[0]
            full_client_id = search_row['client_id']
            searched_installment_id = search_row['searched_installment_id']
            
            logger.info(f"Found installment #{installment_num} for client: {search_row['client_name']} with client_id: {full_client_id}")
            
            # Step 2: Get client info
            client_query = """
            DECLARE $user_id AS Utf8;
            DECLARE $client_id AS Utf8;
            
            SELECT id, full_name
            FROM clients
            WHERE user_id = $user_id AND id = $client_id
            LIMIT 1;
            """
            
            client_params = {
                '$user_id': user_id,
                '$client_id': full_client_id
            }
            
            prepared_client_query = session.prepare(client_query)
            client_result_sets = session.transaction().execute(
                prepared_client_query,
                client_params,
                commit_tx=True
            )
            
            client_rows = list(client_result_sets[0].rows)
            if not client_rows:
                return []
            
            client_row = client_rows[0]
            
            # Step 3: Get all installments for this client - ALL COLUMNS
            installments_query = """
            DECLARE $user_id AS Utf8;
            DECLARE $client_id AS Utf8;
            
            SELECT 
                id,
                user_id,
                client_id,
                product_name,
                cash_price,
                installment_price,
                term_months,
                down_payment,
                monthly_payment,
                down_payment_date,
                installment_start_date,
                installment_end_date,
                created_at,
                updated_at,
                paid_amount,
                remaining_amount,
                next_payment_date,
                next_payment_amount,
                payment_status,
                overdue_count,
                total_payments,
                paid_payments,
                last_payment_date,
                client_name,
                installment_number,
                wallet_id
            FROM installments
            WHERE user_id = $user_id AND client_id = $client_id
            ORDER BY created_at DESC;
            """
            
            installments_params = {
                '$user_id': user_id,
                '$client_id': full_client_id
            }
            
            prepared_installments_query = session.prepare(installments_query)
            installments_result_sets = session.transaction().execute(
                prepared_installments_query,
                installments_params,
                commit_tx=True
            )
            
            # Step 4: Get all payments for all installments of this client
            payments_query = """
            DECLARE $user_id AS Utf8;
            DECLARE $client_id AS Utf8;
            
            SELECT 
                p.id,
                p.installment_id,
                p.payment_number,
                p.due_date,
                p.expected_amount,
                p.is_paid,
                p.paid_date,
                p.created_at,
                p.updated_at,
                p.paid_amount
            FROM installment_payments AS p
            INNER JOIN installments AS i ON p.installment_id = i.id
            WHERE i.user_id = $user_id AND i.client_id = $client_id
            ORDER BY p.installment_id, p.payment_number;
            """
            
            payments_params = {
                '$user_id': user_id,
                '$client_id': full_client_id
            }
            
            prepared_payments_query = session.prepare(payments_query)
            payments_result_sets = session.transaction().execute(
                prepared_payments_query,
                payments_params,
                commit_tx=True
            )
            
            return installments_result_sets[0], payments_result_sets[0], client_row, searched_installment_id
        
        try:
            query_result = pool.retry_operation_sync(execute_query)
            
            # Handle case where no client found
            if not query_result:
                driver.stop()
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                    },
                    'body': json.dumps({
                        'error': 'Installment not found',
                        'message': f'No installment found with number "{installment_number}" and client name containing "{client_name}"'
                    })
                }
            
            installments_result_set, payments_result_set, client_info, searched_installment_id = query_result
            
            def convert_timestamp(ts):
                if ts is None: return None
                return datetime.fromtimestamp(ts / 1000000).isoformat() if isinstance(ts, int) else ts.isoformat()

            def convert_date(d):
                if d is None: return None
                if isinstance(d, date): return d.strftime('%Y-%m-%d')
                if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal()).strftime('%Y-%m-%d')
                return str(d)
            
            # Process payments and group by installment_id
            payments_by_installment = {}
            logger.info(f"Processing {len(list(payments_result_set.rows))} payment rows")
            
            for payment_row in payments_result_set.rows:
                try:
                    # Use dictionary access with table alias prefix
                    installment_id = payment_row['p.installment_id']
                    if installment_id not in payments_by_installment:
                        payments_by_installment[installment_id] = []
                    
                    payment = {
                        'id': payment_row['p.id'],
                        'installment_id': payment_row['p.installment_id'],
                        'payment_number': payment_row['p.payment_number'] or 0,
                        'due_date': convert_date(payment_row['p.due_date']),
                        'expected_amount': float(payment_row['p.expected_amount']) if payment_row['p.expected_amount'] is not None else 0.0,
                        'is_paid': payment_row['p.is_paid'] or False,
                        'paid_date': convert_date(payment_row.get('p.paid_date')),
                        'paid_amount': float(payment_row.get('p.paid_amount')) if payment_row.get('p.paid_amount') is not None else 0.0,
                        'created_at': convert_timestamp(payment_row['p.created_at']),
                        'updated_at': convert_timestamp(payment_row['p.updated_at'])
                    }
                    payments_by_installment[installment_id].append(payment)
                    logger.info(f"Successfully processed payment {payment_row['p.payment_number']} for installment {installment_id}")
                except Exception as e:
                    logger.error(f"Error processing payment row: {e}")
                    logger.error(f"Payment row keys: {list(payment_row.keys()) if hasattr(payment_row, 'keys') else 'No keys method'}")
                    continue
            
            # Process installments and attach payments - ALL FIELDS
            installments = []
            for row in installments_result_set.rows:
                installment = {
                    # Basic identifiers
                    'id': row.id,
                    'user_id': row.user_id,
                    'client_id': row.client_id,
                    'client_name': row.client_name,
                    'wallet_id': row.wallet_id,
                    
                    # Product information
                    'product_name': row.product_name,
                    'installment_number': row.installment_number,
                    
                    # Financial details
                    'cash_price': float(row.cash_price) if row.cash_price else 0.0,
                    'installment_price': float(row.installment_price) if row.installment_price else 0.0,
                    'down_payment': float(row.down_payment) if row.down_payment else 0.0,
                    'monthly_payment': float(row.monthly_payment) if row.monthly_payment else 0.0,
                    
                    # Payment tracking
                    'paid_amount': float(row.paid_amount) if row.paid_amount else 0.0,
                    'remaining_amount': float(row.remaining_amount) if row.remaining_amount else 0.0,
                    'next_payment_amount': float(row.next_payment_amount) if row.next_payment_amount else 0.0,
                    
                    # Terms and schedule
                    'term_months': row.term_months if row.term_months else 0,
                    'total_payments': row.total_payments if row.total_payments else 0,
                    'paid_payments': row.paid_payments if row.paid_payments else 0,
                    
                    # Dates
                    'down_payment_date': convert_date(row.down_payment_date),
                    'installment_start_date': convert_date(row.installment_start_date),
                    'installment_end_date': convert_date(row.installment_end_date),
                    'next_payment_date': convert_date(row.next_payment_date),
                    'last_payment_date': convert_date(row.last_payment_date),
                    'created_at': convert_timestamp(row.created_at),
                    'updated_at': convert_timestamp(row.updated_at),
                    
                    # Status information
                    'payment_status': row.payment_status,
                    'overdue_count': row.overdue_count if row.overdue_count else 0,
                    
                    # Calculated fields for UI convenience
                    'progress_percentage': round((float(row.paid_amount) / float(row.installment_price) * 100) if row.installment_price and row.paid_amount else 0.0, 2),
                    'is_overdue': (row.overdue_count if row.overdue_count else 0) > 0,
                    'is_completed': row.payment_status == 'paid' if row.payment_status else False,
                    
                    # Payment schedule
                    'payments': payments_by_installment.get(row.id, [])
                }
                installments.append(installment)
            
            # Sort installments: searched installment first, then others
            installments.sort(key=lambda x: (x['id'] != searched_installment_id, x['created_at']))
            
            driver.stop()
            
            # Calculate summary statistics with proper overdue amount
            total_amount = sum(inst['installment_price'] for inst in installments)
            total_paid = sum(inst['paid_amount'] for inst in installments)
            total_remaining = sum(inst['remaining_amount'] for inst in installments)
            
            # Calculate total overdue amount from overdue payments
            total_overdue = 0.0
            for inst in installments:
                for payment in inst['payments']:
                    if not payment['is_paid'] and payment['due_date']:
                        try:
                            due_date = datetime.strptime(payment['due_date'], '%Y-%m-%d').date()
                            if due_date < datetime.now().date():
                                total_overdue += payment['expected_amount']
                        except:
                            continue
            
            response_data = {
                'client': {
                    'id': client_info.id,
                    'name': client_info.full_name,
                    'searched_installment_number': int(installment_number)
                },
                'summary': {
                    'total_installments': len(installments),
                    'total_amount': total_amount,
                    'total_paid': total_paid,
                    'total_remaining': total_remaining,
                    'total_overdue': total_overdue
                },
                'installments': installments
            }
            
            logger.info(f"Found {len(installments)} installments for client {client_info.full_name}")
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                },
                'body': json.dumps(response_data)
            }
            
        except ValueError as ve:
            driver.stop()
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                },
                'body': json.dumps({'error': str(ve)})
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
