import os
import json
import ydb
import hmac
import jwt
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

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
    Yandex Cloud Function handler to get current user profile information.
    """
    try:
        logger.info(f"Get user request from IP: {event.get('headers', {}).get('x-forwarded-for', 'unknown')}")
        
        # 1. Authentication
        user_id, auth_error = JWTAuth.authenticate_request(event)
        if not user_id:
            logger.warning(f"Authentication failed: {auth_error}")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': f'Unauthorized: {auth_error}'})
            }
        
        # 2. Database operations
        try:
            # Use metadata authentication
            driver_config = ydb.DriverConfig(
                endpoint=os.environ.get('YDB_ENDPOINT'),
                database=os.environ.get('YDB_DATABASE'),
                credentials=ydb.iam.MetadataUrlCredentials(),
            )
            
            with ydb.Driver(driver_config) as driver:
                driver.wait(fail_fast=True, timeout=5)
                
                with ydb.SessionPool(driver) as pool:
                    def get_user_profile(session):
                        # Get user by ID
                        query = """
                        DECLARE $user_id AS Utf8;
                        SELECT id, email, full_name, phone, created_at, updated_at
                        FROM users 
                        WHERE id = $user_id;
                        """
                        
                        prepared_query = session.prepare(query)
                        result_sets = session.transaction().execute(
                            prepared_query, 
                            {'$user_id': user_id},
                            commit_tx=True
                        )
                        
                        users = []
                        for result_set in result_sets:
                            for row in result_set.rows:
                                users.append(row)
                        
                        if not users:
                            logger.warning(f"User not found: {user_id}")
                            return None
                        
                        user = users[0]
                        
                        # Ensure timestamps are datetime objects before formatting
                        created_at_dt = user.created_at
                        if isinstance(created_at_dt, str):
                            created_at_dt = datetime.fromisoformat(created_at_dt.replace('Z', '+00:00'))

                        updated_at_dt = user.updated_at
                        if isinstance(updated_at_dt, str):
                            updated_at_dt = datetime.fromisoformat(updated_at_dt.replace('Z', '+00:00'))

                        return {
                            'id': user.id,
                            'email': user.email,
                            'full_name': user.full_name,
                            'phone': user.phone,
                            'created_at': created_at_dt.isoformat(),
                            'updated_at': updated_at_dt.isoformat()
                        }
                    
                    user_data = pool.retry_operation_sync(get_user_profile)
                    
                    if not user_data:
                        return {
                            'statusCode': 404,
                            'headers': {'Content-Type': 'application/json'},
                            'body': json.dumps({'error': 'User not found'})
                        }
                    
                    logger.info(f"User profile retrieved successfully: {user_data['email']}")
                    
                    return {
                        'statusCode': 200,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps(user_data)
                    }
        
        except Exception as e:
            logger.error(f"Database error during user retrieval: {e}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Database error during user retrieval'})
            }
    
    except Exception as e:
        logger.error(f"Unexpected error in user retrieval: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        } 