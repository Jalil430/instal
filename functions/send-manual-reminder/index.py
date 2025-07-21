import os
import json
import logging
import ydb
import jwt
import requests
import time
import re
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple

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

def get_whatsapp_settings(user_id: str) -> Optional[Dict[str, Any]]:
    """Get WhatsApp settings for a user"""
    driver = get_ydb_driver()
    try:
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            query = """
                DECLARE $user_id AS Utf8;
                SELECT 
                    user_id,
                    green_api_instance_id,
                    green_api_token,
                    reminder_template_7_days,
                    reminder_template_due_today,
                    reminder_template_manual,
                    is_enabled,
                    created_at,
                    updated_at
                FROM whatsapp_settings 
                WHERE user_id = $user_id;
            """
            
            tx = session.transaction(ydb.SerializableReadWrite())
            result_sets = tx.execute(
                session.prepare(query),
                {'$user_id': user_id}
            )
            tx.commit()
            return result_sets

        result_sets = pool.retry_operation_sync(execute_query)
        
        if result_sets and result_sets[0].rows:
            row = result_sets[0].rows[0]
            return {
                'user_id': row.user_id,
                'green_api_instance_id': row.green_api_instance_id,
                'green_api_token': row.green_api_token,
                'reminder_template_7_days': row.reminder_template_7_days,
                'reminder_template_due_today': row.reminder_template_due_today,
                'reminder_template_manual': row.reminder_template_manual,
                'is_enabled': row.is_enabled,
                'created_at': row.created_at,
                'updated_at': row.updated_at
            }
        
        return None
        
    finally:
        driver.stop()

def get_installments_by_ids(installment_ids: List[str], user_id: str) -> List[Dict[str, Any]]:
    """Get multiple installments by IDs with client information using direct YDB query"""
    if not installment_ids:
        return []
    
    driver = get_ydb_driver()
    try:
        pool = ydb.SessionPool(driver)
        
        def execute_query(session):
            # Build parameters for installment IDs
            id_params = {}
            id_placeholders = []
            
            for i, installment_id in enumerate(installment_ids):
                param_name = f'$id_{i}'
                id_params[param_name] = installment_id
                id_placeholders.append(param_name)
            
            # Query 1: Get installments (exactly like get-installment function)
            installment_query = f"""
                DECLARE $user_id AS Utf8;
                {' '.join([f'DECLARE {param} AS Utf8;' for param in id_params.keys()])}
                SELECT id, user_id, client_id, investor_id, product_name, cash_price, 
                       installment_price, down_payment, term_months, down_payment_date, 
                       installment_start_date, installment_end_date, monthly_payment, 
                       created_at, updated_at
                FROM installments 
                WHERE id IN ({', '.join(id_placeholders)}) AND user_id = $user_id;
            """
            
            # Query 2: Get clients info
            client_query = """
                DECLARE $user_id AS Utf8;
                SELECT id, full_name, contact_number
                FROM clients 
                WHERE user_id = $user_id;
            """
            
            # Query 3: Get unpaid payments
            payment_query = f"""
                {' '.join([f'DECLARE {param} AS Utf8;' for param in id_params.keys()])}
                SELECT installment_id, MIN(due_date) as next_due_date
                FROM installment_payments 
                WHERE installment_id IN ({', '.join(id_placeholders)}) AND is_paid = false
                GROUP BY installment_id;
            """
            
            parameters = {'$user_id': user_id}
            parameters.update(id_params)
            
            tx = session.transaction(ydb.SerializableReadWrite())
            
            # Execute all queries (matching get-installment pattern)
            installment_result_sets = tx.execute(
                session.prepare(installment_query),
                parameters
            )
            
            client_result_sets = tx.execute(
                session.prepare(client_query),
                {'$user_id': user_id}
            )
            
            payment_result_sets = tx.execute(
                session.prepare(payment_query),
                id_params
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
                    
                    logger.info(f"Raw installment data: id={installment_id}, product={product_name}, monthly_payment={monthly_payment}")
                    
                    # Get client info
                    client_info = clients.get(client_id, {})
                    client_name = client_info.get('name', 'Unknown Client')
                    client_phone = client_info.get('phone', 'No Phone')
                    
                    # Get next due date
                    next_due_date_raw = payment_dates.get(installment_id)
                    
                    if next_due_date_raw:
                        # Convert YDB date to Python date (same as get-installment)
                        if isinstance(next_due_date_raw, int):
                            next_due_date = (datetime(1970, 1, 1) + timedelta(days=next_due_date_raw)).date()
                        elif hasattr(next_due_date_raw, 'date'):
                            next_due_date = next_due_date_raw.date()
                        elif isinstance(next_due_date_raw, datetime):
                            next_due_date = next_due_date_raw.date()
                        else:
                            next_due_date = datetime.utcnow().date()
                    else:
                        next_due_date = datetime.utcnow().date() + timedelta(days=30)
                        logger.warning(f"No unpaid payments found for installment {installment_id}")
                    
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
                    
                    logger.info(f"Processed installment: {installment_data}")
                    installments.append(installment_data)
                    
                except Exception as e:
                    logger.error(f"Error processing installment row: {e}")
                    continue
        
        logger.info(f"Found {len(installments)} installments for {len(installment_ids)} requested IDs")
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
            logger.info(f"Manual reminder sent successfully to {installment['client_name']} for installment {installment['installment_id']}")
        else:
            logger.warning(f"Failed to send manual reminder to {installment['client_name']} for installment {installment['installment_id']}: {send_result.get('error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error sending manual reminder for installment {installment['installment_id']}: {e}")
        return {
            'installment_id': installment['installment_id'],
            'client_name': installment.get('client_name', 'unknown'),
            'template_type': template_type,
            'status': 'failed',
            'error': str(e)
        }

def handler(event, context):
    """Yandex Cloud Function handler for manual WhatsApp reminders"""
    try:
        logger.info(f"Manual reminder request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Parse and validate request body
        try:
            raw_body = event.get('body', '{}')
            
            # Handle Base64 encoded body
            try:
                import base64
                decoded_body = base64.b64decode(raw_body).decode('utf-8')
                body = json.loads(decoded_body)
            except Exception:
                body = json.loads(raw_body)
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid JSON in request body'})
            }
        
        # 3. Validate input parameters
        installment_ids = body.get('installment_ids', [])
        template_type = body.get('template_type', 'manual')
        
        # Handle single installment ID (convert to list)
        if isinstance(installment_ids, str):
            installment_ids = [installment_ids]
        
        if not installment_ids or not isinstance(installment_ids, list):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'installment_ids is required and must be a string or array'})
            }
        
        # Limit batch size for performance
        if len(installment_ids) > 50:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Maximum 50 installments can be processed at once'})
            }
        
        logger.info(f"Processing manual reminders for {len(installment_ids)} installments for user {user_id}")
        logger.info(f"Installment IDs: {installment_ids}")
        
        # 4. Get user's WhatsApp settings
        user_settings = get_whatsapp_settings(user_id)
        
        if not user_settings or not user_settings.get('is_enabled'):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'WhatsApp reminders are not enabled for this user'})
            }
        
        if not user_settings.get('green_api_instance_id') or not user_settings.get('green_api_token'):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'WhatsApp credentials are not configured'})
            }
        
        # 5. Initialize WhatsApp service
        whatsapp_service = WhatsAppService(
            instance_id=user_settings['green_api_instance_id'],
            token=user_settings['green_api_token']
        )
        
        # Test WhatsApp connection first
        connection_ok, connection_error = whatsapp_service.test_connection()
        if not connection_ok:
            logger.error(f"WhatsApp connection failed for user {user_id}: {connection_error}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'WhatsApp connection failed: {connection_error}'})
            }
        
        # 6. Get installments data
        installments = get_installments_by_ids(installment_ids, user_id)
        
        if not installments:
            logger.warning(f"No installments found for user {user_id} with IDs: {installment_ids}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Installment not found or access denied'})
            }
        
        # 7. Get appropriate template
        template = get_template_by_type(user_settings, template_type)
        
        # 8. Process reminders
        result = {
            'processed_count': 0,
            'successful_sends': 0,
            'failed_sends': 0,
            'results': []
        }
        
        for installment in installments:
            try:
                reminder_result = send_installment_reminder(
                    installment=installment,
                    template=template,
                    whatsapp_service=whatsapp_service,
                    template_type=template_type
                )
                
                result['processed_count'] += 1
                if reminder_result['status'] == 'success':
                    result['successful_sends'] += 1
                else:
                    result['failed_sends'] += 1
                
                result['results'].append(reminder_result)
                
                # Add delay between messages
                if len(installments) > 1:
                    time.sleep(0.5)
                
            except Exception as e:
                logger.error(f"Error processing installment {installment['installment_id']}: {e}")
                result['processed_count'] += 1
                result['failed_sends'] += 1
                result['results'].append({
                    'installment_id': installment['installment_id'],
                    'client_name': installment.get('client_name', 'unknown'),
                    'status': 'failed',
                    'error': str(e)
                })
        
        # Handle installments that weren't found
        found_ids = {inst['installment_id'] for inst in installments}
        missing_ids = set(installment_ids) - found_ids
        
        for missing_id in missing_ids:
            result['processed_count'] += 1
            result['failed_sends'] += 1
            result['results'].append({
                'installment_id': missing_id,
                'status': 'failed',
                'error': 'Installment not found or access denied'
            })
        
        logger.info(f"Manual reminders completed for user {user_id}: {result['successful_sends']} successful, {result['failed_sends']} failed")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Manual reminder request failed: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
