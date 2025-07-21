import os
import json
import logging
import ydb
import requests
import time
import re
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WhatsAppError(Exception):
    """Custom exception for WhatsApp-related errors"""
    def __init__(self, message: str, error_code: Optional[str] = None, retryable: bool = False):
        self.message = message
        self.error_code = error_code
        self.retryable = retryable
        super().__init__(self.message)

class GreenAPIClient:
    """Green API client for WhatsApp messaging"""
    
    def __init__(self, instance_id: str, token: str):
        self.instance_id = instance_id
        self.token = token
        self.base_url = f"https://api.green-api.com/waInstance{instance_id}"
        self.session = requests.Session()
        self.session.timeout = 30
        
    def send_message(self, phone_number: str, message: str) -> Dict[str, Any]:
        """Send WhatsApp message via Green API"""
        try:
            # Format phone number
            formatted_phone = self._format_phone_number(phone_number)
            
            # Prepare request
            url = f"{self.base_url}/sendMessage/{self.token}"
            payload = {
                "chatId": f"{formatted_phone}@c.us",
                "message": message
            }
            
            logger.info(f"Sending WhatsApp message to {formatted_phone[:5]}****")
            
            response = self.session.post(url, json=payload)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('idMessage'):
                    logger.info(f"Message sent successfully: {result.get('idMessage')}")
                    return result
                else:
                    raise WhatsAppError(
                        f"Message sending failed: {result.get('error', 'Unknown error')}",
                        error_code="SEND_FAILED",
                        retryable=True
                    )
            elif response.status_code == 429:
                raise WhatsAppError(
                    "Rate limit exceeded",
                    error_code="RATE_LIMIT",
                    retryable=True
                )
            elif response.status_code == 401:
                raise WhatsAppError(
                    "Invalid Green API credentials",
                    error_code="AUTH_FAILED",
                    retryable=False
                )
            else:
                raise WhatsAppError(
                    f"HTTP error {response.status_code}: {response.text}",
                    error_code="HTTP_ERROR",
                    retryable=True
                )
                
        except requests.exceptions.Timeout:
            raise WhatsAppError(
                "Request timeout",
                error_code="TIMEOUT",
                retryable=True
            )
        except requests.exceptions.ConnectionError:
            raise WhatsAppError(
                "Connection error",
                error_code="CONNECTION_ERROR",
                retryable=True
            )
        except Exception as e:
            if isinstance(e, WhatsAppError):
                raise
            raise WhatsAppError(
                f"Unexpected error: {str(e)}",
                error_code="UNKNOWN_ERROR",
                retryable=False
            )
    
    def test_connection(self) -> Tuple[bool, Optional[str]]:
        """Test Green API connection and credentials"""
        try:
            url = f"{self.base_url}/getSettings/{self.token}"
            response = self.session.get(url)
            
            if response.status_code == 200:
                return True, None
            elif response.status_code == 401:
                return False, "Invalid credentials"
            else:
                return False, f"Connection test failed: {response.status_code}"
                
        except Exception as e:
            return False, f"Connection error: {str(e)}"
    
    def _format_phone_number(self, phone_number: str) -> str:
        """Format phone number for Green API"""
        # Remove all non-digit characters
        digits_only = re.sub(r'\D', '', phone_number)
        
        # Remove leading + if present
        if digits_only.startswith('7') and len(digits_only) == 11:
            # Russian number format
            return digits_only
        elif digits_only.startswith('8') and len(digits_only) == 11:
            # Convert Russian 8 to 7
            return '7' + digits_only[1:]
        elif len(digits_only) >= 10:
            # International format
            return digits_only
        else:
            raise WhatsAppError(
                f"Invalid phone number format: {phone_number}",
                error_code="INVALID_PHONE",
                retryable=False
            )

class WhatsAppService:
    """Main WhatsApp service class"""
    
    def __init__(self, instance_id: str, token: str):
        self.client = GreenAPIClient(instance_id, token)
    
    def send_reminder(self, phone_number: str, template: str, variables: Dict[str, Any], max_retries: int = 3) -> Dict[str, Any]:
        """Send WhatsApp reminder with retry logic"""
        result = {
            'status': 'failed',
            'message_id': None,
            'error': None,
            'attempts': 0
        }
        
        try:
            # Process template
            message = self.process_template(template, variables)
            
            # Attempt to send with retries
            for attempt in range(max_retries):
                result['attempts'] = attempt + 1
                
                try:
                    response = self.client.send_message(phone_number, message)
                    result['status'] = 'success'
                    result['message_id'] = response.get('idMessage')
                    return result
                    
                except WhatsAppError as e:
                    result['error'] = e.message
                    
                    if not e.retryable or attempt == max_retries - 1:
                        break
                    
                    # Exponential backoff
                    wait_time = 2 ** attempt
                    logger.info(f"Retrying in {wait_time} seconds (attempt {attempt + 1}/{max_retries})")
                    time.sleep(wait_time)
            
            return result
            
        except Exception as e:
            result['error'] = str(e)
            return result
    
    def test_connection(self) -> Tuple[bool, Optional[str]]:
        """Test Green API connection"""
        return self.client.test_connection()
    
    def process_template(self, template: str, variables: Dict[str, Any]) -> str:
        """Process template with variable substitution"""
        try:
            # Ensure all variables are strings
            str_variables = {k: str(v) if v is not None else '' for k, v in variables.items()}
            
            # Replace variables in template
            processed = template.format(**str_variables)
            
            logger.debug(f"Template processed successfully")
            return processed
            
        except KeyError as e:
            logger.error(f"Missing template variable: {e}")
            raise WhatsAppError(
                f"Template processing failed: missing variable {e}",
                error_code="TEMPLATE_ERROR",
                retryable=False
            )
        except Exception as e:
            logger.error(f"Template processing error: {e}")
            raise WhatsAppError(
                f"Template processing failed: {str(e)}",
                error_code="TEMPLATE_ERROR",
                retryable=False
            )

# Default templates
DEFAULT_TEMPLATES = {
    'reminder_7_days': "Здравствуйте, {client_name}! Напоминаем, что ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен через {days_remaining} дней ({due_date}). Пожалуйста, подготовьте средства для оплаты.",
    'reminder_due_today': "Здравствуйте, {client_name}! Ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен сегодня ({due_date}). Пожалуйста, произведите оплату.",
    'reminder_manual': "Здравствуйте, {client_name}! Напоминаем о вашем платеже по рассрочке в размере {installment_amount} руб. за {product_name}. Дата платежа: {due_date}."
}

def get_ydb_driver():
    """Create and return YDB driver"""
    endpoint = os.environ['YDB_ENDPOINT']
    database = os.environ['YDB_DATABASE']
    
    driver_config = ydb.DriverConfig(
        endpoint=endpoint,
        database=database,
        credentials=ydb.iam.MetadataUrlCredentials(),
    )
    
    driver = ydb.Driver(driver_config)
    driver.wait(fail_fast=True)
    return driver

def get_all_enabled_users() -> List[Dict[str, Any]]:
    """Get all users with WhatsApp reminders enabled"""
    driver = get_ydb_driver()
    try:
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            query = """
                SELECT 
                    user_id,
                    green_api_instance_id,
                    green_api_token,
                    reminder_template_7_days,
                    reminder_template_due_today,
                    reminder_template_manual,
                    is_enabled
                FROM whatsapp_settings 
                WHERE is_enabled = true
                AND green_api_instance_id IS NOT NULL
                AND green_api_token IS NOT NULL;
            """
            
            tx = session.transaction(ydb.SerializableReadWrite())
            result_sets = tx.execute(query)
            tx.commit()
            return result_sets

        result_sets = pool.retry_operation_sync(execute_query)
        
        users = []
        if result_sets and result_sets[0].rows:
            for row in result_sets[0].rows:
                users.append({
                    'user_id': row.user_id,
                    'green_api_instance_id': row.green_api_instance_id,
                    'green_api_token': row.green_api_token,
                    'reminder_template_7_days': row.reminder_template_7_days,
                    'reminder_template_due_today': row.reminder_template_due_today,
                    'reminder_template_manual': row.reminder_template_manual,
                    'is_enabled': row.is_enabled
                })
        
        return users
        
    finally:
        driver.stop()

def get_installments_due_in_days(user_id: str, days: int) -> List[Dict[str, Any]]:
    """Get installments that are due in specified number of days"""
    if days < 0:
        return []
    
    driver = get_ydb_driver()
    try:
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            # Query 1: Get all installments for the user
            installment_query = """
                DECLARE $user_id AS Utf8;
                SELECT id, user_id, client_id, investor_id, product_name, cash_price, 
                       installment_price, down_payment, term_months, down_payment_date, 
                       installment_start_date, installment_end_date, monthly_payment, 
                       created_at, updated_at
                FROM installments 
                WHERE user_id = $user_id;
            """
            
            # Query 2: Get clients info
            client_query = """
                DECLARE $user_id AS Utf8;
                SELECT id, full_name, contact_number
                FROM clients 
                WHERE user_id = $user_id;
            """
            
            # Query 3: Get next unpaid payment for each installment
            payment_query = """
                SELECT installment_id, MIN(due_date) as next_due_date
                FROM installment_payments 
                WHERE is_paid = false
                GROUP BY installment_id;
            """
            
            tx = session.transaction(ydb.SerializableReadWrite())
            
            # Execute all queries
            installment_result_sets = tx.execute(
                session.prepare(installment_query),
                {'$user_id': user_id}
            )
            
            client_result_sets = tx.execute(
                session.prepare(client_query),
                {'$user_id': user_id}
            )
            
            payment_result_sets = tx.execute(
                session.prepare(payment_query)
            )
            
            tx.commit()
            return installment_result_sets[0], client_result_sets[0], payment_result_sets[0]

        installment_result, client_result, payment_result = pool.retry_operation_sync(execute_query)
        
        # Create client lookup map
        clients = {}
        if client_result.rows:
            for row in client_result.rows:
                clients[row.id] = {
                    'name': row.full_name,
                    'phone': row.contact_number
                }
        
        # Create payment dates lookup map
        payment_dates = {}
        if payment_result.rows:
            for row in payment_result.rows:
                payment_dates[row.installment_id] = row.next_due_date
        
        # Calculate target date
        target_date = datetime.utcnow().date() + timedelta(days=days)
        
        installments = []
        if installment_result.rows:
            for row in installment_result.rows:
                try:
                    # Access fields exactly like get-installment function
                    installment_id = row.id
                    product_name = row.product_name
                    monthly_payment = float(row.monthly_payment)
                    installment_price = float(row.installment_price)
                    term_months = row.term_months
                    client_id = row.client_id
                    
                    # Get client info
                    client_info = clients.get(client_id, {})
                    client_name = client_info.get('name', 'Unknown Client')
                    client_phone = client_info.get('phone', 'No Phone')
                    
                    # Get next due date from payment_dates map
                    next_due_date_raw = payment_dates.get(installment_id)
                    
                    if next_due_date_raw:
                        # Convert YDB date to Python date
                        if isinstance(next_due_date_raw, int):
                            next_due_date = (datetime(1970, 1, 1) + timedelta(days=next_due_date_raw)).date()
                        elif hasattr(next_due_date_raw, 'date'):
                            next_due_date = next_due_date_raw.date()
                        elif isinstance(next_due_date_raw, datetime):
                            next_due_date = next_due_date_raw.date()
                        else:
                            continue  # Skip if we can't parse the date
                    else:
                        continue  # Skip if no unpaid payments
                    
                    # Only include installments where next_due_date matches target_date
                    if next_due_date != target_date:
                        continue
                    
                    current_date = datetime.utcnow().date()
                    days_remaining = (next_due_date - current_date).days
                    
                    installment_data = {
                        'installment_id': installment_id,
                        'product_name': product_name,
                        'monthly_payment': monthly_payment,
                        'total_price': installment_price,
                        'term_months': term_months,
                        'client_id': client_id,
                        'client_name': client_name,
                        'client_phone': client_phone,
                        'due_date': next_due_date,
                        'days_remaining': days_remaining
                    }
                    
                    installments.append(installment_data)
                    
                except Exception as e:
                    logger.error(f"Error processing installment row: {e}")
                    continue
        
        logger.info(f"Found {len(installments)} installments due in {days} days for user {user_id}")
        return installments
        
    finally:
        driver.stop()

def format_currency(amount: float) -> str:
    """Format currency amount for display"""
    return f"{amount:,.2f}"

def format_date(date_obj) -> str:
    """Format date for display in messages"""
    if isinstance(date_obj, datetime):
        return date_obj.strftime("%d.%m.%Y")
    elif hasattr(date_obj, 'strftime'):
        return date_obj.strftime("%d.%m.%Y")
    else:
        return str(date_obj)

def get_template_by_type(user_settings: Dict[str, Any], template_type: str) -> str:
    """Get message template by type"""
    template_map = {
        'manual': user_settings.get('reminder_template_manual') or DEFAULT_TEMPLATES['reminder_manual'],
        '7_days': user_settings.get('reminder_template_7_days') or DEFAULT_TEMPLATES['reminder_7_days'],
        'due_today': user_settings.get('reminder_template_due_today') or DEFAULT_TEMPLATES['reminder_due_today']
    }
    
    return template_map.get(template_type, template_map['manual'])

def send_installment_reminder(installment: Dict[str, Any], template: str, whatsapp_service: WhatsAppService, template_type: str) -> Dict[str, Any]:
    """Send WhatsApp reminder for a specific installment"""
    try:
        # Prepare template variables
        variables = {
            'client_name': installment['client_name'],
            'installment_amount': format_currency(installment['monthly_payment']),
            'due_date': format_date(installment['due_date']),
            'days_remaining': str(installment['days_remaining']),
            'product_name': installment['product_name'] or 'товар',
            'total_amount': format_currency(installment['total_price'])
        }
        
        # Send reminder
        send_result = whatsapp_service.send_reminder(
            phone_number=installment['client_phone'],
            template=template,
            variables=variables
        )
        
        result = {
            'installment_id': installment['installment_id'],
            'client_name': installment['client_name'],
            'client_phone': installment['client_phone'][:5] + '****',  # Mask phone for logging
            'template_type': template_type,
            'status': send_result['status'],
            'message_id': send_result.get('message_id'),
            'error': send_result.get('error'),
            'attempts': send_result.get('attempts', 0)
        }
        
        if send_result['status'] == 'success':
            logger.info(f"Auto reminder sent successfully to {installment['client_name']} for installment {installment['installment_id']}")
        else:
            logger.warning(f"Failed to send auto reminder to {installment['client_name']} for installment {installment['installment_id']}: {send_result.get('error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error sending auto reminder for installment {installment['installment_id']}: {e}")
        return {
            'installment_id': installment['installment_id'],
            'client_name': installment.get('client_name', 'unknown'),
            'template_type': template_type,
            'status': 'failed',
            'error': str(e)
        }

def process_user_reminders(user_settings: Dict[str, Any]) -> Dict[str, Any]:
    """Process automatic reminders for a specific user"""
    user_id = user_settings['user_id']
    result = {
        'user_id': user_id,
        'processed_count': 0,
        'successful_sends': 0,
        'failed_sends': 0,
        'results': []
    }
    
    try:
        # Initialize WhatsApp service
        whatsapp_service = WhatsAppService(
            instance_id=user_settings['green_api_instance_id'],
            token=user_settings['green_api_token']
        )
        
        # Test connection first
        connection_ok, connection_error = whatsapp_service.test_connection()
        if not connection_ok:
            logger.error(f"WhatsApp connection failed for user {user_id}: {connection_error}")
            result['error'] = f'WhatsApp connection failed: {connection_error}'
            return result
        
        # Get installments due in 7 days
        installments_7_days = get_installments_due_in_days(user_id, 7)
        template_7_days = get_template_by_type(user_settings, '7_days')
        
        # Get installments due today
        installments_today = get_installments_due_in_days(user_id, 0)
        template_today = get_template_by_type(user_settings, 'due_today')
        
        # Process 7-day reminders
        for installment in installments_7_days:
            try:
                reminder_result = send_installment_reminder(
                    installment=installment,
                    template=template_7_days,
                    whatsapp_service=whatsapp_service,
                    template_type='7_days'
                )
                
                result['processed_count'] += 1
                if reminder_result['status'] == 'success':
                    result['successful_sends'] += 1
                else:
                    result['failed_sends'] += 1
                
                result['results'].append(reminder_result)
                
                # Add delay between messages
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error processing 7-day reminder for installment {installment['installment_id']}: {e}")
                result['processed_count'] += 1
                result['failed_sends'] += 1
                result['results'].append({
                    'installment_id': installment['installment_id'],
                    'client_name': installment.get('client_name', 'unknown'),
                    'template_type': '7_days',
                    'status': 'failed',
                    'error': str(e)
                })
        
        # Process due today reminders
        for installment in installments_today:
            try:
                reminder_result = send_installment_reminder(
                    installment=installment,
                    template=template_today,
                    whatsapp_service=whatsapp_service,
                    template_type='due_today'
                )
                
                result['processed_count'] += 1
                if reminder_result['status'] == 'success':
                    result['successful_sends'] += 1
                else:
                    result['failed_sends'] += 1
                
                result['results'].append(reminder_result)
                
                # Add delay between messages
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error processing due today reminder for installment {installment['installment_id']}: {e}")
                result['processed_count'] += 1
                result['failed_sends'] += 1
                result['results'].append({
                    'installment_id': installment['installment_id'],
                    'client_name': installment.get('client_name', 'unknown'),
                    'template_type': 'due_today',
                    'status': 'failed',
                    'error': str(e)
                })
        
        logger.info(f"Auto reminders completed for user {user_id}: {result['successful_sends']} successful, {result['failed_sends']} failed")
        return result
        
    except Exception as e:
        logger.error(f"Failed to process auto reminders for user {user_id}: {e}")
        result['error'] = str(e)
        return result

def handler(event, context):
    """
    Yandex Cloud Function handler for automatic WhatsApp reminders
    This function is triggered by a timer (cron job) to send automatic reminders
    """
    try:
        logger.info("Starting automatic WhatsApp reminders processing")
        
        # Get all users with WhatsApp enabled
        enabled_users = get_all_enabled_users()
        
        if not enabled_users:
            logger.info("No users with WhatsApp reminders enabled")
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'message': 'No users with WhatsApp reminders enabled',
                    'processed_users': 0,
                    'total_reminders': 0
                })
            }
        
        logger.info(f"Processing automatic reminders for {len(enabled_users)} users")
        
        # Process reminders for each user
        total_results = {
            'processed_users': 0,
            'total_processed': 0,
            'total_successful': 0,
            'total_failed': 0,
            'user_results': []
        }
        
        for user_settings in enabled_users:
            try:
                user_result = process_user_reminders(user_settings)
                
                total_results['processed_users'] += 1
                total_results['total_processed'] += user_result['processed_count']
                total_results['total_successful'] += user_result['successful_sends']
                total_results['total_failed'] += user_result['failed_sends']
                total_results['user_results'].append(user_result)
                
                # Add delay between users to avoid rate limiting
                time.sleep(2)
                
            except Exception as e:
                logger.error(f"Error processing user {user_settings['user_id']}: {e}")
                total_results['processed_users'] += 1
                total_results['user_results'].append({
                    'user_id': user_settings['user_id'],
                    'error': str(e),
                    'processed_count': 0,
                    'successful_sends': 0,
                    'failed_sends': 0
                })
        
        logger.info(f"Automatic reminders completed: {total_results['total_successful']} successful, {total_results['total_failed']} failed across {total_results['processed_users']} users")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Automatic reminders processing completed',
                'summary': {
                    'processed_users': total_results['processed_users'],
                    'total_reminders_processed': total_results['total_processed'],
                    'total_successful_sends': total_results['total_successful'],
                    'total_failed_sends': total_results['total_failed']
                },
                'details': total_results['user_results']
            })
        }
        
    except Exception as e:
        logger.error(f"Automatic reminders processing failed: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
