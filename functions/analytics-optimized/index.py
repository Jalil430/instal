import os
import json
import ydb
import jwt
import logging
from datetime import datetime, date, timedelta
from typing import Optional, Tuple

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
    Yandex Cloud Function handler to get optimized analytics data.
    """
    if event.get('httpMethod') == 'OPTIONS':
        return _cors({'statusCode': 200, 'headers': DEFAULT_CORS_HEADERS, 'body': ''})

    try:
        # CRITICAL DEBUG LOGGING - Will always show up in logs
        print("========== ANALYTICS FUNCTION STARTED ==========")
        print(f"EVENT: {json.dumps(event)}")
        print(f"QUERY PARAMS: {event.get('queryStringParameters')}")
        
        logger.info(f"ANALYTICS REQUEST - Full event: {json.dumps(event)}")
        logger.info(f"ANALYTICS REQUEST - HTTP method: {event.get('httpMethod')}")
        logger.info(f"ANALYTICS REQUEST - Path: {event.get('path')}")
        logger.info(f"ANALYTICS REQUEST - Query params: {event.get('queryStringParameters')}")
        
        # Extract user_id and client_date from query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        query_user_id = query_params.get('user_id')
        client_date_str = query_params.get('client_date')
        wallet_id = query_params.get('wallet_id')
        
        print(f"QUERY EXTRACTED - user_id: {query_user_id}, client_date: {client_date_str}, wallet_id: {wallet_id}")
        logger.info(f"ANALYTICS REQUEST - Extracted user_id from query: {query_user_id}")
        logger.info(f"ANALYTICS REQUEST - Extracted client_date: {client_date_str}")
        logger.info(f"ANALYTICS REQUEST - Wallet filter: {wallet_id}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
        # If no user_id from auth, use the one from query params
        if not user_id and query_user_id:
            user_id = query_user_id
            print(f"USING USER_ID FROM QUERY: {user_id}")
        
        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)

            def get_analytics_from_db(session):
                # Use client date if provided, otherwise use server date
                today = date.today()
                print(f"INITIAL SERVER DATE: {today}")
                
                if client_date_str:
                    print(f"CLIENT DATE STRING PROVIDED: {client_date_str}")
                    try:
                        today = date.fromisoformat(client_date_str)
                        print(f"USING CLIENT DATE: {today}")
                        logger.info(f"Using client date: {today}")
                    except ValueError:
                        print(f"INVALID CLIENT DATE FORMAT: {client_date_str}, USING SERVER DATE: {today}")
                        logger.error(f"Invalid client_date format: {client_date_str}, using server date: {today}")
                else:
                    print(f"NO CLIENT DATE PROVIDED, USING SERVER DATE: {today}")
                    logger.info(f"No client_date provided, using server date: {today}")

                # Calculate date ranges
                seven_days_ago = today - timedelta(days=7)
                thirty_days_ago = today - timedelta(days=30)
                
                # Calculate current week (Monday-Sunday)
                current_weekday = today.weekday()  # 0=Monday, 6=Sunday
                current_week_start = today - timedelta(days=current_weekday)  # Monday
                current_week_end = current_week_start + timedelta(days=6)  # Sunday
                
                # Calculate previous week
                previous_week_start = current_week_start - timedelta(days=7)
                previous_week_end = current_week_end - timedelta(days=7)
                
                logger.info(f"Date calculations: today={today}, seven_days_ago={seven_days_ago}, thirty_days_ago={thirty_days_ago}")
                logger.info(f"Week calculations: current_week={current_week_start} to {current_week_end}, previous_week={previous_week_start} to {previous_week_end}")
                
                # Convert dates to strings for YDB query parameters
                today_str = today.isoformat()
                seven_days_ago_str = seven_days_ago.isoformat()
                thirty_days_ago_str = thirty_days_ago.isoformat()
                
                # Get installments data
                wallet_declaration = ""
                wallet_filter_clause = ""
                if wallet_id:
                    wallet_declaration = "DECLARE $wallet_id AS Utf8;\n"
                    wallet_filter_clause = " AND wallet_id = $wallet_id"
                
                installments_query = f"""
                DECLARE $user_id AS Utf8;
                {wallet_declaration}DECLARE $thirty_days_ago AS Date;
                
                SELECT 
                    installment_price,
                    COALESCE(cash_price, CAST(0 AS Decimal(22,9))) as cash_price,
                    COALESCE(paid_amount, CAST(0 AS Decimal(22,9))) as paid_amount,
                    COALESCE(remaining_amount, installment_price) as remaining_amount,
                    COALESCE(payment_status, 'предстоящий') as payment_status,
                    COALESCE(overdue_count, CAST(0 AS Int32)) as overdue_count,
                    next_payment_date,
                    COALESCE(next_payment_amount, CAST(0 AS Decimal(22,9))) as next_payment_amount,
                    created_at,
                    id as installment_id,
                    term_months,
                    product_name,
                    client_name,
                    COALESCE(down_payment, CAST(0 AS Decimal(22,9))) as down_payment,
                    down_payment_date
                FROM installments
                WHERE user_id = $user_id{wallet_filter_clause};
                """
                
                prepared_query = session.prepare(installments_query)
                params = {
                    '$user_id': user_id,
                    '$thirty_days_ago': thirty_days_ago
                }
                if wallet_id:
                    params['$wallet_id'] = wallet_id
                
                result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                    prepared_query,
                    params,
                    commit_tx=True
                )
                
                installments = []
                for row in result_sets[0].rows:
                    def convert_timestamp(ts):
                        if ts is None: return None
                        return datetime.fromtimestamp(ts / 1000000) if isinstance(ts, int) else ts

                    def convert_date(d):
                        if d is None: return None
                        if isinstance(d, date): return d
                        if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal())
                        return d

                    installment = {
                        'installment_price': float(row.installment_price),
                        'cash_price': float(row.cash_price),
                        'paid_amount': float(row.paid_amount),
                        'remaining_amount': float(row.remaining_amount),
                        'payment_status': row.payment_status,
                        'overdue_count': row.overdue_count,
                        'next_payment_date': convert_date(row.next_payment_date),
                        'next_payment_amount': float(row.next_payment_amount),
                        'created_at': convert_timestamp(row.created_at),
                        'id': row.installment_id,
                        'term_months': getattr(row, 'term_months', 0),
                        'product_name': getattr(row, 'product_name', None),
                        'client_name': getattr(row, 'client_name', None),
                        'down_payment': float(getattr(row, 'down_payment', 0.0) or 0.0),
                        'down_payment_date': convert_date(getattr(row, 'down_payment_date', None))
                    }
                    installments.append(installment)
                
                # Get user's installment IDs for payment filtering
                user_installment_ids = [installment['id'] for installment in installments]
                logger.info(f"Found {len(user_installment_ids)} installments for user")
                
                if not user_installment_ids:
                    logger.warning("No installments found for user, returning empty analytics")
                    return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({
                        'key_metrics': {'total_revenue': 0, 'new_installments': 0, 'collection_rate': 0, 'portfolio_growth': 0},
                        'total_sales': {'weekly_sales': [0, 0, 0, 0, 0, 0, 0], 'average_sales': 0},
                        'installment_status': {'overdue_count': 0, 'due_to_pay_count': 0, 'upcoming_count': 0, 'paid_count': 0},
                        'installment_details': {'active_installments': 0, 'total_portfolio': 0, 'total_cash_price': 0, 'total_overdue': 0, 'average_installment_value': 0},
                        'profit_analytics': {
                            'profit': {'months': [], 'total_overdue': 0.0},
                            'revenue': {'months': [], 'total_overdue': 0.0},
                            'default_basis': 'profit'
                        }
                    })}
                
                # Get ALL payments data for this user's installments (no date filtering yet)
                payments_query = """
                DECLARE $installment_ids AS List<Utf8>;
                
                SELECT 
                    id,
                    installment_id,
                    expected_amount,
                    paid_date,
                    is_paid,
                    payment_number,
                    due_date,
                    paid_amount
                FROM installment_payments 
                WHERE installment_id IN $installment_ids;
                """
                
                try:
                    prepared_payments_query = session.prepare(payments_query)
                    payments_result = session.transaction(ydb.SerializableReadWrite()).execute(
                        prepared_payments_query,
                        {
                            '$installment_ids': user_installment_ids
                        },
                        commit_tx=True
                    )
                    
                    # Process payments (both paid and scheduled)
                    paid_payments = []
                    scheduled_payments = []
                    rows = payments_result[0].rows
                    logger.info(f"Payment query returned {len(rows)} rows")
                    
                    for i, row in enumerate(rows):
                        try:
                            # Access fields safely
                            payment_id = getattr(row, 'id', None)
                            installment_id = getattr(row, 'installment_id', None)
                            expected_amount = getattr(row, 'expected_amount', 0.0) or 0.0
                            paid_amount = getattr(row, 'paid_amount', None)
                            paid_date_raw = getattr(row, 'paid_date', None)
                            due_date_raw = getattr(row, 'due_date', None)
                            is_paid = bool(getattr(row, 'is_paid', False))
                            payment_number = getattr(row, 'payment_number', None)
                            
                            def convert_date(d):
                                if d is None: return None
                                if isinstance(d, date): return d
                                if isinstance(d, int): return date.fromordinal(d + date(1970, 1, 1).toordinal())
                                return d
                            
                            paid_date = convert_date(paid_date_raw)
                            due_date = convert_date(due_date_raw)
                            
                            scheduled_payments.append({
                                'payment_id': payment_id,
                                'installment_id': installment_id,
                                'expected_amount': float(expected_amount),
                                'due_date': due_date,
                                'is_paid': is_paid,
                                'payment_number': payment_number,
                                'paid_amount': float(paid_amount) if paid_amount is not None else None,
                                'paid_date': paid_date
                            })
                            
                            if paid_date and installment_id and is_paid:
                                payment = {
                                    'payment_id': payment_id,
                                    'installment_id': installment_id,
                                    'paid_amount': float(paid_amount) if paid_amount is not None else float(expected_amount),
                                    'payment_date': paid_date,
                                    'payment_number': payment_number
                                }
                                paid_payments.append(payment)
                                logger.info(f"Processed payment: {payment['paid_amount']} on {payment['payment_date']}")
                        except Exception as e:
                            logger.error(f"Error processing payment row {i}: {e}")
                            continue
                    
                    logger.info(f"Successfully processed {len(paid_payments)} paid payments and {len(scheduled_payments)} scheduled payments")
                    
                except Exception as e:
                    logger.warning(f"Failed to fetch payment data: {e}. Using installment data only.")
                    paid_payments = []
                    scheduled_payments = []
                
                # Calculate analytics from the data
                analytics_data = calculate_analytics(
                    installments=installments, 
                    paid_payments=paid_payments, 
                    scheduled_payments=scheduled_payments,
                    today=today,
                    current_week_start=current_week_start,
                    current_week_end=current_week_end,
                    previous_week_start=previous_week_start,
                    previous_week_end=previous_week_end,
                    thirty_days_ago=thirty_days_ago
                )
                
                logger.info(f"Generated analytics for {len(installments)} installments and {len(paid_payments)} paid payments")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(analytics_data)}

            result = pool.retry_operation_sync(get_analytics_from_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})}

def calculate_analytics(installments, paid_payments, scheduled_payments, today, current_week_start, current_week_end, previous_week_start, previous_week_end, thirty_days_ago):
    """
    Calculate analytics data from installments and payments.
    
    Handles:
    - Current week (Monday to Sunday) vs previous week comparison
    - Proper percentage changes between weeks
    - Consistent metrics across all sections
    - Always shows current week even if no payments
    """
    
    # Initialize counters
    total_revenue = 0.0
    total_portfolio = 0.0
    total_cash_price = 0.0
    fallback_total_overdue = 0.0
    upcoming_revenue_30_days = 0.0
    
    # Status counters
    overdue_count = 0
    due_to_pay_count = 0
    upcoming_count = 0
    paid_count = 0
    
    # New installments counter
    new_installments_30_days = 0
    new_installments_current_week = 0
    new_installments_previous_week = 0
    
    # Filter payments by date ranges
    current_week_payments = [
        p for p in paid_payments 
        if p['payment_date'] and current_week_start <= p['payment_date'] <= current_week_end
    ]
    
    previous_week_payments = [
        p for p in paid_payments 
        if p['payment_date'] and previous_week_start <= p['payment_date'] <= previous_week_end
    ]
    
    # Log payment counts for debugging
    logger.info(f"Found {len(current_week_payments)} payments in current week and {len(previous_week_payments)} in previous week")
    
    # Calculate total overdue amount from scheduled payments when available.
    scheduled_total_overdue = None
    if scheduled_payments:
        scheduled_total_overdue = 0.0
        for payment in scheduled_payments:
            if not payment or payment.get('is_paid'):
                continue
            due_date = payment.get('due_date')
            if not due_date:
                continue
            if isinstance(due_date, datetime):
                due_date = due_date.date()
            elif isinstance(due_date, str):
                try:
                    due_date = date.fromisoformat(due_date)
                except ValueError:
                    continue
            if due_date < today:
                scheduled_total_overdue += float(payment.get('expected_amount', 0.0) or 0.0)
        logger.info(f"Calculated overdue total from schedule: {scheduled_total_overdue}")
    else:
        logger.info("No scheduled_payments provided for overdue calculation")
    
    # Weekly sales arrays (Monday=0, Tuesday=1, ..., Sunday=6)
    current_week_sales = [0.0] * 7
    previous_week_sales = [0.0] * 7
    
    # Process current week payments
    for payment in current_week_payments:
        payment_date = payment['payment_date']
        paid_amount = payment['paid_amount']
        
        if payment_date:
            # Map to weekday: Monday=0, Tuesday=1, ..., Sunday=6
            weekday_index = payment_date.weekday()
            current_week_sales[weekday_index] += paid_amount
            logger.info(f"Current week payment: {paid_amount} on {payment_date} (weekday {weekday_index})")
    
    # Process previous week payments
    for payment in previous_week_payments:
        payment_date = payment['payment_date']
        paid_amount = payment['paid_amount']
        
        if payment_date:
            weekday_index = payment_date.weekday()
            previous_week_sales[weekday_index] += paid_amount
            logger.info(f"Previous week payment: {paid_amount} on {payment_date} (weekday {weekday_index})")
    
    # Calculate week totals and averages
    current_week_total = sum(current_week_sales)
    previous_week_total = sum(previous_week_sales)
    
    # Calculate daily averages (divide by 7 days)
    current_week_avg = current_week_total / 7
    previous_week_avg = previous_week_total / 7 if previous_week_total > 0 else 0.0
    
    # Calculate percentage change
    percentage_change = None
    if previous_week_avg > 0:
        percentage_change = ((current_week_avg - previous_week_avg) / previous_week_avg) * 100
    
    def normalize_payment_status(status: Optional[str]) -> str:
        """Return canonical Russian status even if old English values are stored."""
        if not status:
            return 'предстоящий'
        status_str = str(status).strip().lower()
        mapping = {
            'overdue': 'просрочено',
            'late': 'просрочено',
            'due': 'к оплате',
            'due today': 'к оплате',
            'pending': 'предстоящий',
            'scheduled': 'предстоящий',
            'upcoming': 'предстоящий',
            'paid': 'оплачено',
            'completed': 'оплачено',
            'оплачен': 'оплачено',
        }
        if status_str in ('просрочено', 'к оплате', 'предстоящий', 'оплачено'):
            return status_str
        return mapping.get(status_str, 'предстоящий')

    def derive_installment_status(installment) -> str:
        """
        Determine the most accurate status for analytics. We can't rely solely on stored payment_status
        because many rows never get status updates after creation. Instead we combine payment_status,
        overdue_count, remaining amounts, and next payment date relative to `today`.
        """
        normalized_status = normalize_payment_status(installment.get('payment_status'))
        overdue_count_val = installment.get('overdue_count', 0) or 0
        remaining_amount = installment.get('remaining_amount', 0.0) or 0.0
        paid_amount = installment.get('paid_amount', 0.0) or 0.0
        installment_price = installment.get('installment_price', 0.0) or 0.0
        next_payment_date = installment.get('next_payment_date')

        # Completed installments should always fall into the paid bucket
        if (
            normalized_status == 'оплачено'
            or (installment_price > 0 and (paid_amount >= installment_price or remaining_amount <= 0))
        ):
            return 'оплачено'

        # Any overdue count recorded in YDB or overdue status wins immediately
        if overdue_count_val > 0 or normalized_status == 'просрочено':
            return 'просрочено'

        # Fall back to comparing the next payment date with the date used for analytics
        if next_payment_date:
            if isinstance(next_payment_date, datetime):
                next_payment_date = next_payment_date.date()
            if next_payment_date < today:
                return 'просрочено'
            if next_payment_date == today:
                return 'к оплате'
            return 'предстоящий'

        # Without a next payment date we trust whatever status we have (or default to upcoming)
        if normalized_status in ('к оплате', 'предстоящий'):
            return normalized_status
        return 'предстоящий'

    # Process installments for portfolio metrics
    for installment in installments:
        installment_price = installment['installment_price']
        cash_price = installment['cash_price']
        paid_amount = installment['paid_amount']
        remaining_amount = installment['remaining_amount']
        payment_status = derive_installment_status(installment)
        next_payment_date = installment['next_payment_date']
        next_payment_amount = installment['next_payment_amount']
        created_at = installment['created_at']
        
        # Total revenue is sum of all paid amounts from installments
        total_revenue += paid_amount
        
        # Total portfolio is sum of all installment prices
        total_portfolio += installment_price
        
        # Total cash price is sum of all cash prices
        total_cash_price += cash_price
        
        # Count by status
        if payment_status == 'просрочено':
            overdue_count += 1
            fallback_total_overdue += remaining_amount
        elif payment_status == 'к оплате':
            due_to_pay_count += 1
        elif payment_status == 'предстоящий':
            upcoming_count += 1
        elif payment_status == 'оплачено':
            paid_count += 1
        
        # Upcoming revenue in next 30 days
        if next_payment_date and next_payment_date <= today + timedelta(days=30):
            upcoming_revenue_30_days += next_payment_amount
        
        # New installments in last 30 days
        if created_at and created_at.date() >= thirty_days_ago:
            new_installments_30_days += 1
            
            # Count new installments by week
            if created_at.date() >= current_week_start and created_at.date() <= current_week_end:
                new_installments_current_week += 1
            elif created_at.date() >= previous_week_start and created_at.date() <= previous_week_end:
                new_installments_previous_week += 1
    
    # Calculate derived metrics
    active_installments = overdue_count + due_to_pay_count + upcoming_count
    collection_rate = (total_revenue / total_portfolio * 100) if total_portfolio > 0 else 0.0
    average_installment_value = total_portfolio / len(installments) if installments else 0.0
    
    # Calculate average term in months
    total_term_months = sum(installment.get('term_months', 0) for installment in installments)
    average_term = total_term_months / len(installments) if installments else 0.0
    logger.info(f"Total term months: {total_term_months}, Average term: {average_term:.1f} months")
    
    # Calculate percentage changes for key metrics
    new_installments_change = None
    if new_installments_previous_week > 0:
        new_installments_change = ((new_installments_current_week - new_installments_previous_week) / new_installments_previous_week) * 100
    
    # For now, we don't have historical data for these metrics
    total_revenue_change = None
    collection_rate_change = None
    portfolio_growth_change = None
    
    # Generate chart data for line charts (simple x,y mapping)
    chart_data = [{'x': i, 'y': current_week_sales[i]} for i in range(7)]
    
    # Debug logging
    logger.info(f"Current week sales: {current_week_sales}, total: {current_week_total}")
    logger.info(f"Previous week sales: {previous_week_sales}, total: {previous_week_total}")
    logger.info(f"Average per day: current={current_week_avg}, previous={previous_week_avg}, change={percentage_change}%")
    logger.info(f"Total revenue: {total_revenue}, Collection rate: {collection_rate:.1f}%")
    
    # Format percentage change for display
    formatted_percentage_change = None
    if percentage_change is not None:
        formatted_percentage_change = percentage_change
    
    profit_analytics = calculate_profit_analytics(installments, scheduled_payments, paid_payments, today)

    logger.info(
        "Overdue totals: scheduled_total_overdue=%s fallback_total_overdue=%s final_total_overdue=%s",
        scheduled_total_overdue,
        fallback_total_overdue,
        scheduled_total_overdue if scheduled_total_overdue is not None else fallback_total_overdue,
    )

    return {
        'key_metrics': {
            'total_revenue': total_revenue,
            'total_revenue_change': total_revenue_change,
            'total_revenue_chart_data': chart_data,
            'new_installments': new_installments_30_days,
            'new_installments_change': new_installments_change,
            'new_installments_chart_data': chart_data,
            'collection_rate': collection_rate,
            'collection_rate_change': collection_rate_change,
            'collection_rate_chart_data': chart_data,
            'portfolio_growth': total_portfolio,
            'portfolio_growth_change': portfolio_growth_change,
            'portfolio_growth_chart_data': chart_data,
        },
        'total_sales': {
            'weekly_sales': current_week_sales,  # Direct mapping: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
            'average_sales': current_week_avg,
            'percentage_change': formatted_percentage_change,
        },
        'installment_status': {
            'overdue_count': overdue_count,
            'due_to_pay_count': due_to_pay_count,
            'upcoming_count': upcoming_count,
            'paid_count': paid_count,
        },
        'installment_details': {
            'active_installments': active_installments,
            'total_portfolio': total_portfolio,
            'total_cash_price': total_cash_price,
            'total_overdue': scheduled_total_overdue if scheduled_total_overdue is not None else fallback_total_overdue,
            'average_installment_value': average_installment_value,
            'average_term': average_term,
            'total_installment_value': total_portfolio,
            'upcoming_revenue_30_days': upcoming_revenue_30_days,
        },
        'profit_analytics': profit_analytics
    }

def calculate_profit_analytics(installments, scheduled_payments, paid_payments, today):
    empty_payload = {
        'profit': {'months': [], 'total_overdue': 0.0},
        'revenue': {'months': [], 'total_overdue': 0.0},
        'default_basis': 'profit',
    }

    if not installments:
        return empty_payload

    installment_lookup = {inst['id']: inst for inst in installments}

    def profit_ratio(inst):
        installment_price = inst.get('installment_price', 0.0) or 0.0
        cash_price = inst.get('cash_price', 0.0) or 0.0
        if installment_price <= 0:
            return None
        ratio = (installment_price - cash_price) / installment_price
        return ratio if ratio > 0 else None

    def month_key(dt):
        return date(dt.year, dt.month, 1)

    def normalize_to_date(val):
        if val is None:
            return None
        if isinstance(val, datetime):
            return val.date()
        if isinstance(val, date):
            return val
        if isinstance(val, str):
            try:
                return date.fromisoformat(val)
            except ValueError:
                return None
        return None

    def empty_bucket():
        return {
            'expected_daily': {},
            'received_daily': {},
            'overdue': 0.0,
            'outside_month_paid': 0.0,
        }

    metrics = {
        'profit': {'months': {}, 'total_overdue': 0.0, 'seen_paid_keys': set()},
        'revenue': {'months': {}, 'total_overdue': 0.0, 'seen_paid_keys': set()},
    }

    def get_bucket(metric_name, dt):
        normalized = normalize_to_date(dt)
        if not normalized:
            return None
        key = month_key(normalized)
        metric = metrics[metric_name]
        bucket = metric['months'].setdefault(key, empty_bucket())
        return bucket, normalized

    def paid_dedupe_key(payment, normalized_paid, amount):
        payment_id = payment.get('payment_id')
        if payment_id:
            return (payment_id,)
        payment_number = payment.get('payment_number')
        if payment_number is not None:
            return (
                payment.get('installment_id'),
                payment_number,
                normalized_paid.isoformat(),
            )
        return (
            payment.get('installment_id'),
            normalized_paid.isoformat(),
            float(amount),
        )

    for payment in scheduled_payments or []:
        installment_id = payment.get('installment_id')
        inst = installment_lookup.get(installment_id)
        if not inst:
            continue

        expected_amount_raw = payment.get('expected_amount', 0.0) or 0.0
        if expected_amount_raw <= 0:
            continue

        due_date = normalize_to_date(payment.get('due_date'))
        paid_date = normalize_to_date(payment.get('paid_date'))
        is_paid = payment.get('is_paid', False)
        paid_amount_raw = payment.get('paid_amount', None)

        for metric_name in ('profit', 'revenue'):
            ratio = profit_ratio(inst) if metric_name == 'profit' else 1.0
            if ratio is None:
                continue

            # Expected view should sum ONLY unpaid scheduled payments.
            if not is_paid and due_date:
                bucket_tuple = get_bucket(metric_name, due_date)
                if bucket_tuple:
                    bucket, normalized_due = bucket_tuple
                    day = normalized_due.day
                    expected_amount = expected_amount_raw * ratio
                    existing = bucket['expected_daily'].get(day, {
                        'expected_amount': 0.0,
                        'paid_amount': 0.0,
                        'is_overdue': False
                    })
                    existing['expected_amount'] += expected_amount
                    existing['is_overdue'] = existing['is_overdue'] or (normalized_due < today)
                    bucket['expected_daily'][day] = existing

                    if normalized_due < today:
                        bucket['overdue'] += expected_amount
                        metrics[metric_name]['total_overdue'] += expected_amount

            if is_paid and paid_date:
                bucket_tuple = get_bucket(metric_name, paid_date)
                if bucket_tuple:
                    bucket, normalized_paid = bucket_tuple
                    paid_base_amount = paid_amount_raw if paid_amount_raw is not None else expected_amount_raw
                    paid_amount = (paid_base_amount or 0.0) * ratio
                    paid_amount_normalized = paid_amount
                    key = paid_dedupe_key(payment, normalized_paid, paid_amount_normalized)
                    seen_paid_keys = metrics[metric_name]['seen_paid_keys']
                    if key in seen_paid_keys:
                        continue
                    seen_paid_keys.add(key)

                    day_paid = normalized_paid.day
                    bucket['received_daily'][day_paid] = bucket['received_daily'].get(day_paid, {
                        'amount': 0.0,
                    })
                    bucket['received_daily'][day_paid]['amount'] += paid_amount

                    if due_date and (normalized_paid.month != due_date.month or normalized_paid.year != due_date.year):
                        bucket['outside_month_paid'] += paid_amount

    for payment in paid_payments or []:
        installment_id = payment.get('installment_id')
        inst = installment_lookup.get(installment_id)
        if not inst:
            continue
        paid_amount_raw = payment.get('paid_amount', 0.0) or 0.0
        paid_date = normalize_to_date(payment.get('payment_date'))
        if not paid_date or paid_amount_raw <= 0:
            continue

        for metric_name in ('profit', 'revenue'):
            ratio = profit_ratio(inst) if metric_name == 'profit' else 1.0
            if ratio is None:
                continue
            paid_amount = paid_amount_raw * ratio

            bucket_tuple = get_bucket(metric_name, paid_date)
            if not bucket_tuple:
                continue
            bucket, normalized_paid = bucket_tuple

            key = paid_dedupe_key(payment, normalized_paid, paid_amount)
            seen_paid_keys = metrics[metric_name]['seen_paid_keys']
            if key in seen_paid_keys:
                continue
            seen_paid_keys.add(key)

            day = normalized_paid.day
            bucket['received_daily'][day] = bucket['received_daily'].get(day, {
                'amount': 0.0,
            })
            bucket['received_daily'][day]['amount'] += paid_amount

            # Expected view should remain unpaid-only; no mirroring for paid entries.

    def transform_metric(metric_name):
        metric = metrics[metric_name]
        month_items = []
        for month_dt, bucket in metric['months'].items():
            expected_daily = [
                {
                    'day': day,
                    'expected_amount': round(values.get('expected_amount', 0.0), 2),
                    'paid_amount': round(values.get('paid_amount', 0.0), 2),
                    'is_overdue': bool(values.get('is_overdue', False)),
                }
                for day, values in sorted(bucket['expected_daily'].items())
            ]

            received_daily = [
                {
                    'day': day,
                    'amount': round(values.get('amount', 0.0), 2),
                }
                for day, values in sorted(bucket['received_daily'].items())
            ]

            month_items.append({
                'month': month_dt.isoformat(),
                'expected_daily': expected_daily,
                'received_daily': received_daily,
                'overdue_amount': round(bucket.get('overdue', 0.0), 2),
                'outside_month_paid': round(bucket.get('outside_month_paid', 0.0), 2),
            })

        month_items.sort(key=lambda m: m['month'])
        return {
            'months': month_items,
            'total_overdue': round(metric['total_overdue'], 2),
        }

    default_basis = 'revenue'
    if metrics['profit']['months'] and not metrics['revenue']['months']:
        default_basis = 'profit'

    payload = {
        'profit': transform_metric('profit'),
        'revenue': transform_metric('revenue'),
        'default_basis': default_basis,
    }

    return payload
