import os
import ydb
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

logger = logging.getLogger(__name__)

class DatabaseManager:
    """Database utility class for YDB operations"""
    
    def __init__(self):
        self.endpoint = os.environ.get('YDB_ENDPOINT')
        self.database = os.environ.get('YDB_DATABASE')
        
        if not self.endpoint or not self.database:
            raise ValueError("YDB_ENDPOINT and YDB_DATABASE environment variables are required")
    
    def get_driver(self):
        """Create and return YDB driver"""
        driver_config = ydb.DriverConfig(
            endpoint=self.endpoint,
            database=self.database,
            credentials=ydb.iam.MetadataUrlCredentials()
        )
        
        driver = ydb.Driver(driver_config)
        driver.wait(fail_fast=True, timeout=5)
        return driver
    
    def execute_query(self, query: str, parameters: Optional[Dict[str, Any]] = None):
        """Execute a query with optional parameters"""
        driver = self.get_driver()
        try:
            pool = ydb.SessionPool(driver)
            
            def execute_in_session(session):
                if parameters:
                    prepared_query = session.prepare(query)
                    return session.transaction().execute(
                        prepared_query,
                        parameters,
                        commit_tx=True
                    )
                else:
                    return session.transaction().execute(
                        query,
                        commit_tx=True
                    )
            
            return pool.retry_operation_sync(execute_in_session)
        finally:
            driver.stop()
    
    def create_whatsapp_settings_table(self):
        """Create WhatsApp settings table if it doesn't exist"""
        create_table_query = """
        CREATE TABLE IF NOT EXISTS whatsapp_settings (
            user_id Utf8 NOT NULL,
            green_api_instance_id Utf8,
            green_api_token Utf8,
            reminder_template_7_days Utf8,
            reminder_template_due_today Utf8,
            reminder_template_manual Utf8,
            is_enabled Bool DEFAULT false,
            created_at Timestamp,
            updated_at Timestamp,
            PRIMARY KEY (user_id)
        );
        """
        
        try:
            self.execute_query(create_table_query)
            logger.info("WhatsApp settings table created successfully")
        except Exception as e:
            logger.error(f"Failed to create WhatsApp settings table: {e}")
            raise

class WhatsAppSettingsRepository:
    """Repository for WhatsApp settings operations"""
    
    def __init__(self):
        self.db = DatabaseManager()
    
    def get_settings(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get WhatsApp settings for a user"""
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
        
        try:
            result_sets = self.db.execute_query(query, {'$user_id': user_id})
            
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
            
        except Exception as e:
            logger.error(f"Failed to get WhatsApp settings for user {user_id}: {e}")
            raise
    
    def save_settings(self, user_id: str, settings: Dict[str, Any]) -> bool:
        """Save or update WhatsApp settings for a user"""
        current_time = datetime.utcnow()
        
        # Check if settings exist
        existing_settings = self.get_settings(user_id)
        
        if existing_settings:
            # Update existing settings
            query = """
            DECLARE $user_id AS Utf8;
            DECLARE $green_api_instance_id AS Utf8?;
            DECLARE $green_api_token AS Utf8?;
            DECLARE $reminder_template_7_days AS Utf8?;
            DECLARE $reminder_template_due_today AS Utf8?;
            DECLARE $reminder_template_manual AS Utf8?;
            DECLARE $is_enabled AS Bool?;
            DECLARE $updated_at AS Timestamp;
            
            UPDATE whatsapp_settings SET
                green_api_instance_id = $green_api_instance_id,
                green_api_token = $green_api_token,
                reminder_template_7_days = $reminder_template_7_days,
                reminder_template_due_today = $reminder_template_due_today,
                reminder_template_manual = $reminder_template_manual,
                is_enabled = $is_enabled,
                updated_at = $updated_at
            WHERE user_id = $user_id;
            """
        else:
            # Insert new settings
            query = """
            DECLARE $user_id AS Utf8;
            DECLARE $green_api_instance_id AS Utf8?;
            DECLARE $green_api_token AS Utf8?;
            DECLARE $reminder_template_7_days AS Utf8?;
            DECLARE $reminder_template_due_today AS Utf8?;
            DECLARE $reminder_template_manual AS Utf8?;
            DECLARE $is_enabled AS Bool?;
            DECLARE $created_at AS Timestamp;
            DECLARE $updated_at AS Timestamp;
            
            INSERT INTO whatsapp_settings (
                user_id, green_api_instance_id, green_api_token,
                reminder_template_7_days, reminder_template_due_today, reminder_template_manual,
                is_enabled, created_at, updated_at
            ) VALUES (
                $user_id, $green_api_instance_id, $green_api_token,
                $reminder_template_7_days, $reminder_template_due_today, $reminder_template_manual,
                $is_enabled, $created_at, $updated_at
            );
            """
        
        parameters = {
            '$user_id': user_id,
            '$green_api_instance_id': settings.get('green_api_instance_id'),
            '$green_api_token': settings.get('green_api_token'),
            '$reminder_template_7_days': settings.get('reminder_template_7_days'),
            '$reminder_template_due_today': settings.get('reminder_template_due_today'),
            '$reminder_template_manual': settings.get('reminder_template_manual'),
            '$is_enabled': settings.get('is_enabled', False),
            '$updated_at': current_time
        }
        
        if not existing_settings:
            parameters['$created_at'] = current_time
        
        try:
            self.db.execute_query(query, parameters)
            logger.info(f"WhatsApp settings saved for user {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save WhatsApp settings for user {user_id}: {e}")
            raise
    
    def get_enabled_users_settings(self) -> List[Dict[str, Any]]:
        """Get settings for all users with WhatsApp enabled"""
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
        
        try:
            result_sets = self.db.execute_query(query)
            
            settings_list = []
            if result_sets and result_sets[0].rows:
                for row in result_sets[0].rows:
                    settings_list.append({
                        'user_id': row.user_id,
                        'green_api_instance_id': row.green_api_instance_id,
                        'green_api_token': row.green_api_token,
                        'reminder_template_7_days': row.reminder_template_7_days,
                        'reminder_template_due_today': row.reminder_template_due_today,
                        'reminder_template_manual': row.reminder_template_manual,
                        'is_enabled': row.is_enabled
                    })
            
            return settings_list
            
        except Exception as e:
            logger.error(f"Failed to get enabled users settings: {e}")
            raise

def initialize_whatsapp_database():
    """Initialize WhatsApp-related database tables"""
    try:
        db = DatabaseManager()
        db.create_whatsapp_settings_table()
        logger.info("WhatsApp database initialization completed")
    except Exception as e:
        logger.error(f"WhatsApp database initialization failed: {e}")
        raise