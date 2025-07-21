import os
import json
import requests
import logging
import time
import re
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timedelta

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
        """
        Send WhatsApp message via Green API
        
        Args:
            phone_number: Phone number in international format
            message: Message text to send
            
        Returns:
            API response dictionary
            
        Raises:
            WhatsAppError: If message sending fails
        """
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
        """
        Test Green API connection and credentials
        
        Returns:
            Tuple of (success, error_message)
        """
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
        """
        Format phone number for Green API
        
        Args:
            phone_number: Raw phone number
            
        Returns:
            Formatted phone number without + prefix
        """
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

class MessageTemplateProcessor:
    """Processes message templates with variable substitution"""
    
    # Default templates
    DEFAULT_TEMPLATES = {
        'reminder_7_days': "Здравствуйте, {client_name}! Напоминаем, что ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен через {days_remaining} дней ({due_date}). Пожалуйста, подготовьте средства для оплаты.",
        'reminder_due_today': "Здравствуйте, {client_name}! Ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен сегодня ({due_date}). Пожалуйста, произведите оплату.",
        'reminder_manual': "Здравствуйте, {client_name}! Напоминаем о вашем платеже по рассрочке в размере {installment_amount} руб. за {product_name}. Дата платежа: {due_date}."
    }
    
    @staticmethod
    def process_template(template: str, variables: Dict[str, Any]) -> str:
        """
        Process template with variable substitution
        
        Args:
            template: Template string with {variable} placeholders
            variables: Dictionary of variable values
            
        Returns:
            Processed message string
        """
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
    
    @staticmethod
    def validate_template(template: str) -> Tuple[bool, List[str]]:
        """
        Validate template format and extract variables
        
        Args:
            template: Template string to validate
            
        Returns:
            Tuple of (is_valid, list_of_variables)
        """
        try:
            # Extract variables from template
            import string
            formatter = string.Formatter()
            variables = [field_name for _, field_name, _, _ in formatter.parse(template) if field_name]
            
            # Check for valid variable names
            valid_variables = {
                'client_name', 'installment_amount', 'due_date', 
                'days_remaining', 'product_name', 'total_amount'
            }
            
            invalid_vars = [var for var in variables if var not in valid_variables]
            
            if invalid_vars:
                logger.warning(f"Invalid template variables: {invalid_vars}")
                return False, invalid_vars
            
            return True, variables
            
        except Exception as e:
            logger.error(f"Template validation error: {e}")
            return False, [str(e)]

class WhatsAppService:
    """Main WhatsApp service class"""
    
    def __init__(self, instance_id: str, token: str):
        self.client = GreenAPIClient(instance_id, token)
        self.template_processor = MessageTemplateProcessor()
    
    def send_reminder(self, phone_number: str, template: str, variables: Dict[str, Any], max_retries: int = 3) -> Dict[str, Any]:
        """
        Send WhatsApp reminder with retry logic
        
        Args:
            phone_number: Client phone number
            template: Message template
            variables: Template variables
            max_retries: Maximum retry attempts
            
        Returns:
            Result dictionary with status and details
        """
        result = {
            'status': 'failed',
            'message_id': None,
            'error': None,
            'attempts': 0
        }
        
        try:
            # Process template
            message = self.template_processor.process_template(template, variables)
            
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

def create_whatsapp_service(instance_id: str, token: str) -> WhatsAppService:
    """Factory function to create WhatsApp service instance"""
    return WhatsAppService(instance_id, token)