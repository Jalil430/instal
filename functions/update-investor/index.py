import os
import json
import ydb
import re
import hmac
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
from decimal import Decimal

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecurityValidator:
    """Handles input validation and sanitization"""

    @staticmethod
    def validate_investor_id(investor_id: str) -> tuple[str, Optional[str]]:
        """Validate and sanitize investor ID"""
        if not investor_id:
            return None, "Investor ID is required"
        
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, investor_id.lower()):
            return None, "Invalid investor ID format"
        
        return investor_id.lower(), None

    @staticmethod
    def validate_and_sanitize_input(data: dict) -> Tuple[dict, list]:
        """Validate and sanitize input data for updates"""
        errors = []
        sanitized = {}
        
        validation_rules = {
            'user_id': {'type': str, 'min_length': 1, 'max_length': 50, 'pattern': r'^[a-zA-Z0-9_-]+$'},
            'full_name': {'type': str, 'min_length': 1, 'max_length': 100},  # No pattern restriction
            'investment_amount': {'type': (int, float)},
            'investor_percentage': {'type': (int, float)},
            'user_percentage': {'type': (int, float)},
        }
        
        for field, rules in validation_rules.items():
            if field not in data:
                continue

            value = data.get(field)
            
            if value is None:
                sanitized[field] = None
                continue
            
            if not isinstance(value, rules['type']):
                errors.append(f'{field} must be a number' if 'amount' in field or 'percentage' in field else f'{field} must be a string')
                continue
            
            if 'min_length' in rules and len(value) < rules['min_length']:
                errors.append(f'{field} must be at least {rules["min_length"]} characters')
            
            if 'max_length' in rules and len(value) > rules['max_length']:
                errors.append(f'{field} must be no more than {rules["max_length"]} characters')

            # Pattern validation (only if pattern is defined)
            if rules.get('pattern') and isinstance(value, str) and not re.match(rules['pattern'], value):
                errors.append(f'{field} contains invalid characters')
                continue
            
            # Sanitize string fields (trim whitespace only, preserve Unicode characters)
            if isinstance(value, str):
                sanitized[field] = value.strip()
            else:
                sanitized[field] = value
        
        return sanitized, errors

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
            logger.warning("No API key in request")
            return False
        
        return hmac.compare_digest(expected_api_key, api_key)

def handler(event, context):
    """
    Yandex Cloud Function handler to update an investor by ID.
    """
    try:
        logger.info(f"Received update request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        if not ApiKeyAuth.validate_api_key(event):
            return {'statusCode': 401, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Unauthorized'})}
        
        path_params = event.get('pathParameters', {})
        investor_id = path_params.get('id')
        
        sanitized_id, validation_error = SecurityValidator.validate_investor_id(investor_id)
        if validation_error:
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': validation_error})}
        
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
            return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Invalid JSON'})}
        
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
            
            def update_investor_in_db(session):
                # First, check if the investor exists (using same pattern as get-investor)
                check_query = """
                DECLARE $investor_id AS Utf8;
                SELECT id FROM investors WHERE id = $investor_id;
                """
                prepared_check = session.prepare(check_query)
                result_sets = session.transaction().execute(
                    prepared_check, 
                    {'$investor_id': sanitized_id}, 
                    commit_tx=True
                )
                if not result_sets[0].rows:
                    return {'statusCode': 404, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Investor not found'})}

                # Build a simple UPDATE query for the provided field(s)
                if not sanitized_data:
                    return {'statusCode': 400, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'No fields to update'})}

                # Handle common fields with static queries
                current_time = datetime.utcnow()
                
                # Handle full_name update
                if 'full_name' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $full_name AS Utf8;
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET full_name = $full_name, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$full_name': sanitized_data['full_name'],
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                # Handle investment_amount update
                if 'investment_amount' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $investment_amount AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET investment_amount = $investment_amount, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$investment_amount': Decimal(str(sanitized_data['investment_amount'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                # Handle investor_percentage update
                if 'investor_percentage' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $investor_percentage AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET investor_percentage = $investor_percentage, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$investor_percentage': Decimal(str(sanitized_data['investor_percentage'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )
                
                # Handle user_percentage update
                if 'user_percentage' in sanitized_data:
                    update_query = """
                    DECLARE $investor_id AS Utf8;
                    DECLARE $user_percentage AS Decimal(22,9);
                    DECLARE $updated_at AS Timestamp;
                    UPDATE investors 
                    SET user_percentage = $user_percentage, updated_at = $updated_at 
                    WHERE id = $investor_id;
                    """
                    
                    prepared_update = session.prepare(update_query)
                    session.transaction().execute(
                        prepared_update,
                        {
                            '$investor_id': sanitized_id,
                            '$user_percentage': Decimal(str(sanitized_data['user_percentage'])),
                            '$updated_at': current_time
                        },
                        commit_tx=True
                    )

                logger.info(f"Investor updated successfully: {sanitized_id}")
                return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'message': 'Investor updated successfully'})}

            return pool.retry_operation_sync(update_investor_in_db)
            
        except ydb.Error as e:
            logger.error(f"YDB error: {str(e)}")
            return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Database operation failed'})}
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'error': 'Internal server error'})} 