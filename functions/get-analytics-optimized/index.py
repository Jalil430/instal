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
    try:
        logger.info(f"Received analytics request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': f'Unauthorized: {auth_error}'})}
        
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
                # Get current date for calculations
                today = date.today()
                thirty_days_ago = today - timedelta(days=30)
                
                # Single query to get all installment data with calculated fields
                installments_query = """
                DECLARE $user_id AS Utf8;
                
                SELECT 
                    installment_price,
                    COALESCE(paid_amount, CAST(0 AS Decimal(22,9))) as paid_amount,
                    COALESCE(remaining_amount, installment_price) as remaining_amount,
                    COALESCE(payment_status, 'предстоящий') as payment_status,
                    COALESCE(overdue_count, CAST(0 AS Int32)) as overdue_count,
                    next_payment_date,
                    COALESCE(next_payment_amount, CAST(0 AS Decimal(22,9))) as next_payment_amount,
                    created_at
                FROM installments
                WHERE user_id = $user_id;
                """
                
                prepared_query = session.prepare(installments_query)
                result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                    prepared_query,
                    {
                        '$user_id': user_id
                    },
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
                        'paid_amount': float(row.paid_amount),
                        'remaining_amount': float(row.remaining_amount),
                        'payment_status': row.payment_status,
                        'overdue_count': row.overdue_count,
                        'next_payment_date': convert_date(row.next_payment_date),
                        'next_payment_amount': float(row.next_payment_amount),
                        'created_at': convert_timestamp(row.created_at)
                    }
                    installments.append(installment)
                
                # Calculate analytics from the data
                analytics_data = calculate_analytics(installments, today, thirty_days_ago)
                
                logger.info(f"Generated analytics for {len(installments)} installments")
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

def calculate_analytics(installments, today, thirty_days_ago):
    """Calculate analytics data from installments"""
    
    # Initialize counters
    total_revenue = 0.0
    total_portfolio = 0.0
    total_overdue = 0.0
    upcoming_revenue_30_days = 0.0
    
    # Status counters
    overdue_count = 0
    due_to_pay_count = 0
    upcoming_count = 0
    paid_count = 0
    
    # For time-based calculations
    new_installments_30_days = 0
    weekly_sales = [0.0] * 7  # Last 7 days
    
    for installment in installments:
        installment_price = installment['installment_price']
        paid_amount = installment['paid_amount']
        remaining_amount = installment['remaining_amount']
        payment_status = installment['payment_status']
        next_payment_date = installment['next_payment_date']
        next_payment_amount = installment['next_payment_amount']
        created_at = installment['created_at']
        
        # Total revenue is sum of all paid amounts
        total_revenue += paid_amount
        
        # Total portfolio is sum of all installment prices
        total_portfolio += installment_price
        
        # Count by status
        if payment_status == 'просрочено':
            overdue_count += 1
            total_overdue += remaining_amount
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
        
        # Weekly sales (last 7 days)
        if created_at:
            days_ago = (today - created_at.date()).days
            if 0 <= days_ago < 7:
                weekly_sales[6 - days_ago] += installment_price
    
    # Calculate derived metrics
    active_installments = overdue_count + due_to_pay_count + upcoming_count
    collection_rate = (total_revenue / total_portfolio * 100) if total_portfolio > 0 else 0.0
    average_installment_value = total_portfolio / len(installments) if installments else 0.0
    average_sales = sum(weekly_sales) / 7
    
    # Generate chart data (simplified - just use weekly sales for now)
    chart_data = [{'x': i, 'y': weekly_sales[i]} for i in range(7)]
    
    return {
        'key_metrics': {
            'total_revenue': total_revenue,
            'total_revenue_change': None,  # Would need historical data
            'total_revenue_chart_data': chart_data,
            'new_installments': new_installments_30_days,
            'new_installments_change': None,  # Would need historical data
            'new_installments_chart_data': chart_data,
            'collection_rate': collection_rate,
            'collection_rate_change': None,  # Would need historical data
            'collection_rate_chart_data': chart_data,
            'portfolio_growth': total_portfolio,
            'portfolio_growth_change': None,  # Would need historical data
            'portfolio_growth_chart_data': chart_data,
        },
        'total_sales': {
            'weekly_sales': weekly_sales,
            'average_sales': average_sales,
            'percentage_change': None,  # Would need historical data
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
            'total_overdue': total_overdue,
            'average_installment_value': average_installment_value,
            'average_term': 0.0,  # Would need to calculate from term_months
            'total_installment_value': total_portfolio,
            'upcoming_revenue_30_days': upcoming_revenue_30_days,
        }
    }