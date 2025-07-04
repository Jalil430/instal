import os
import json
import ydb
import re
import hmac
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecurityValidator:
    """Handles input validation and sanitization"""

    @staticmethod
    def validate_client_id(client_id: str) -> tuple[str, Optional[str]]:
        """Validate and sanitize client ID"""
        if not client_id:
            return None, "Client ID is required"
        
        # UUID format validation
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, client_id.lower()):
            return None, "Invalid client ID format"
        
        # Sanitize - convert to lowercase
        return client_id.lower(), None

    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data for updates"""
        errors = []
        sanitized = {}
        
        # Define validation rules, all fields are optional for update
        validation_rules = {
            'user_id': {
                'type': str, 'min_length': 1, 'max_length': 50, 'pattern': r'^[a-zA-Z0-9_-]+$'
            },
            'full_name': {
                'type': str, 'min_length': 1, 'max_length': 100, 'pattern': r'^[a-zA-ZÀ-ÿ\s\'-]+$'
            },
            'contact_number': {
                'type': str, 'min_length': 10, 'max_length': 20, 'pattern': r'^\+?[1-9]\d{1,14}$'
            },
            'passport_number': {
                'type': str, 'min_length': 6, 'max_length': 20, 'pattern': r'^[A-Z0-9]+$'
            },
            'address': {
                'type': str, 'min_length': 0, 'max_length': 255, 'pattern': r'^[a-zA-ZÀ-ÿ0-9\s\.,\'-]*$'
            }
        }
        
        for field, rules in validation_rules.items():
            if field not in data:
                continue

            value = data.get(field)
            
            if value is None or value == '':
                sanitized[field] = None
                continue
            
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a string')
                continue
            
            if len(value) < rules['min_length']:
                errors.append(f'{field} must be at least {rules["min_length"]} characters')
                continue
            
            if len(value) > rules['max_length']:
                errors.append(f'{field} must be no more than {rules["max_length"]} characters')
                continue
            
            if rules['pattern'] and not re.match(rules['pattern'], value):
                errors.append(f'{field} contains invalid characters')
                continue
            
            sanitized_value = value.strip()
            if field == 'passport_number':
                sanitized_value = sanitized_value.upper()
            elif field == 'contact_number':
                sanitized_value = re.sub(r'[^\d+]', '', sanitized_value)
            
            sanitized[field] = sanitized_value
        
        return sanitized, errors

class ApiKeyAuth:
    """Handles API key authentication"""
    
    @staticmethod
    def validate_api_key(event: dict) -> bool:
        """Validate API key from request headers"""
        expected_api_key = os.environ.get('API_KEY')
        if not expected_api_key:
            logger.warning("API_KEY not configured in environment")
            return False
        
        headers = event.get('headers', {})
        api_key = None
        for key, value in headers.items():
            if key.lower() == 'x-api-key':
                api_key = value
                break
        
        if not api_key:
            logger.warning("No API key provided in request")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function handler to update a client by ID.
    """
    try:
        logger.info(f"Received update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            logger.warning("Unauthorized access attempt")
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized: Invalid or missing API key'})}
        
        path_params = event.get('pathParameters', {})
        client_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_client_id(client_id)
        if validation_error:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': validation_error})}
        
        try:
            body = json.loads(event.get('body', '{}'))
        except json.JSONDecodeError:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON in request body'})}
        
        if not body:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Request body cannot be empty'})}

        sanitized_data, validation_errors = SecurityValidator.validate_and_sanitize_input(body)
        if validation_errors:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Validation failed', 'details': validation_errors})}

        try:
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials()
            )
            driver = ydb.Driver(driver_config)
            driver.wait(fail_fast=True, timeout=5)
            pool = ydb.SessionPool(driver)
            
            def update_client_in_db(session):
                # First, check if the client exists
                check_query = "DECLARE $client_id AS Utf8; SELECT id FROM clients WHERE id = $client_id;"
                prepared_check = session.prepare(check_query)
                result_sets = session.transaction().execute(prepared_check, {'$client_id': sanitized_id}, commit_tx=True)
                if not result_sets[0].rows:
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Client not found'})}

                # Dynamically build the UPDATE query
                update_parts = []
                params = {'$id': sanitized_id}
                declarations = ['DECLARE $id AS Utf8;', 'DECLARE $updated_at AS Timestamp;']
                
                # YDB types for declaration
                ydb_types = {
                    'user_id': 'Utf8',
                    'full_name': 'Utf8',
                    'contact_number': 'Utf8',
                    'passport_number': 'Utf8',
                    'address': 'Utf8?',
                }

                for key, value in sanitized_data.items():
                    update_parts.append(f"{key} = ${key}")
                    params[f'${key}'] = value
                    declarations.append(f"DECLARE ${key} AS {ydb_types[key]};")
                
                params['$updated_at'] = datetime.utcnow()
                update_parts.append('updated_at = $updated_at')

                update_query_str = f"""
                {' '.join(declarations)}
                UPDATE clients SET {', '.join(update_parts)} WHERE id = $id;
                """
                
                session.transaction().execute(
                    update_query_str,
                    params,
                    commit_tx=True
                )
                
                logger.info(f"Client updated successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Client updated successfully'})}

            result = pool.retry_operation_sync(update_client_in_db)
            driver.stop()
            return result
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 