import os
import ydb
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from database_utils import DatabaseManager

logger = logging.getLogger(__name__)

class InstallmentRepository:
    """Repository for installment-related database operations"""
    
    def __init__(self):
        self.db = DatabaseManager()
    
    def get_installments_due_in_days(self, user_id: str, days: int) -> List[Dict[str, Any]]:
        """
        Get installments that are due in specified number of days
        
        Args:
            user_id: User ID to filter installments
            days: Number of days from today (0 for today, 7 for 7 days from now)
            
        Returns:
            List of installment dictionaries with client information
        """
        # Calculate target date
        target_date = datetime.utcnow().date() + timedelta(days=days)
        
        # Query to get all active installments for the user
        query = """
        DECLARE $user_id AS Utf8;
        
        SELECT 
            i.id as installment_id,
            COALESCE(i.product_name, 'Unknown Product') as product_name,
            i.monthly_payment,
            i.installment_price as total_price,
            i.down_payment_date as installment_start_date,
            i.term_months,
            c.id as client_id,
            c.full_name as client_name,
            c.contact_number as client_phone
        FROM installments i
        JOIN clients c ON i.client_id = c.id
        WHERE i.user_id = $user_id
        AND c.user_id = $user_id;
        """
        
        try:
            result_sets = self.db.execute_query(query, {
                '$user_id': user_id
            })
            
            installments = []
            if result_sets and result_sets[0].rows:
                for row in result_sets[0].rows:
                    try:
                        # Safely access fields with default values if they're None
                        product_name = row.product_name if hasattr(row, 'product_name') and row.product_name is not None else 'Unknown Product'
                        monthly_payment = float(getattr(row, 'monthly_payment', 0) or 0)

                        total_price = float(row.total_price) if hasattr(row, 'total_price') and row.total_price is not None else 0.0
                        term_months = int(row.term_months) if hasattr(row, 'term_months') and row.term_months is not None else 0
                        
                        # Convert integer date to datetime object if needed
                        start_date = None
                        if hasattr(row, 'installment_start_date') and row.installment_start_date is not None:
                            start_date = row.installment_start_date
                            if isinstance(start_date, int):
                                # Convert timestamp to datetime
                                from datetime import datetime
                                start_date = datetime.fromtimestamp(start_date).date()
                        else:
                            # Use current date if start_date is None
                            from datetime import datetime
                            start_date = datetime.utcnow().date()
                        
                        # Calculate all payment due dates for this installment
                        payment_dates = []
                        for month_offset in range(term_months):
                            try:
                                # Calculate payment date for this month
                                payment_year = start_date.year + (start_date.month + month_offset - 1) // 12
                                payment_month = ((start_date.month + month_offset - 1) % 12) + 1
                                
                                # Handle end-of-month dates
                                import calendar
                                last_day = calendar.monthrange(payment_year, payment_month)[1]
                                payment_day = min(start_date.day, last_day)
                                
                                payment_date = datetime(payment_year, payment_month, payment_day).date()
                                payment_dates.append(payment_date)
                                
                            except ValueError:
                                continue
                        
                        # Check if target_date matches any payment date
                        if target_date in payment_dates:
                            installments.append({
                                'installment_id': row.installment_id if hasattr(row, 'installment_id') and row.installment_id is not None else f"unknown_{len(installments)}",
                                'product_name': product_name,
                                'monthly_payment': monthly_payment,
                                'total_price': total_price,
                                'installment_start_date': start_date,
                                'term_months': term_months,
                                'client_id': row.client_id if hasattr(row, 'client_id') and row.client_id is not None else 'unknown',
                                'client_name': row.client_name if hasattr(row, 'client_name') and row.client_name is not None else 'Unknown Client',
                                'client_phone': row.client_phone if hasattr(row, 'client_phone') and row.client_phone is not None else 'No Phone',
                                'due_date': target_date,
                                'days_remaining': days
                            })
                    except Exception as e:
                        logger.error(f"Error processing installment row: {e}")
                        # Continue with next installment
                        continue
            
            logger.info(f"Found {len(installments)} installments due in {days} days for user {user_id}")
            return installments
            
        except Exception as e:
            logger.error(f"Failed to get installments due in {days} days for user {user_id}: {e}")
            raise
    
    def get_installment_by_id(self, installment_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get specific installment by ID with client information
        
        Args:
            installment_id: Installment ID
            user_id: User ID for authorization
            
        Returns:
            Installment dictionary with client information or None
        """
        query = """
        DECLARE $installment_id AS Utf8;
        DECLARE $user_id AS Utf8;
        
        SELECT 
            i.id as installment_id,
            COALESCE(i.product_name, 'Unknown Product') as product_name,
            i.monthly_payment,
            i.installment_price as total_price,
            i.down_payment_date as installment_start_date,
            i.term_months,
            c.id as client_id,
            c.full_name as client_name,
            c.contact_number as client_phone
        FROM installments i
        JOIN clients c ON i.client_id = c.id
        WHERE i.id = $installment_id
        AND i.user_id = $user_id
        AND c.user_id = $user_id;
        """
        
        try:
            result_sets = self.db.execute_query(query, {
                '$installment_id': installment_id,
                '$user_id': user_id
            })
            
            if result_sets and result_sets[0].rows:
                row = result_sets[0].rows[0]
                
                try:
                    # Safely access fields with default values if they're None
                    product_name = row.product_name if hasattr(row, 'product_name') and row.product_name is not None else 'Unknown Product'
                    monthly_payment = float(getattr(row, 'monthly_payment', 0) or 0)

                    total_price = float(row.total_price) if hasattr(row, 'total_price') and row.total_price is not None else 0.0
                    term_months = int(row.term_months) if hasattr(row, 'term_months') and row.term_months is not None else 0
                    
                    # Convert integer date to datetime object if needed
                    start_date = None
                    if hasattr(row, 'installment_start_date') and row.installment_start_date is not None:
                        start_date = row.installment_start_date
                        if isinstance(start_date, int):
                            # Convert timestamp to datetime
                            from datetime import datetime
                            start_date = datetime.fromtimestamp(start_date).date()
                    else:
                        # Use current date if start_date is None
                        from datetime import datetime
                        start_date = datetime.utcnow().date()
                    
                    current_date = datetime.utcnow().date()
                    
                    # Calculate months since start
                    months_since_start = (current_date.year - start_date.year) * 12 + (current_date.month - start_date.month)
                    
                    # Next payment date
                    next_payment_month = start_date.month + months_since_start + 1
                    next_payment_year = start_date.year + (next_payment_month - 1) // 12
                    next_payment_month = ((next_payment_month - 1) % 12) + 1
                    
                    try:
                        next_due_date = datetime(next_payment_year, next_payment_month, start_date.day).date()
                    except ValueError:
                        # Handle month-end dates (e.g., Jan 31 -> Feb 28)
                        import calendar
                        last_day = calendar.monthrange(next_payment_year, next_payment_month)[1]
                        next_due_date = datetime(next_payment_year, next_payment_month, min(start_date.day, last_day)).date()
                    
                    days_remaining = (next_due_date - current_date).days
                    
                    return {
                        'installment_id': row.installment_id if hasattr(row, 'installment_id') and row.installment_id is not None else installment_id,
                        'product_name': product_name,
                        'monthly_payment': monthly_payment,
                        'total_price': total_price,
                        'installment_start_date': start_date,
                        'term_months': term_months,
                        'client_id': row.client_id if hasattr(row, 'client_id') and row.client_id is not None else 'unknown',
                        'client_name': row.client_name if hasattr(row, 'client_name') and row.client_name is not None else 'Unknown Client',
                        'client_phone': row.client_phone if hasattr(row, 'client_phone') and row.client_phone is not None else 'No Phone',
                        'due_date': next_due_date,
                        'days_remaining': days_remaining
                    }
                except Exception as e:
                    logger.error(f"Error processing installment row: {e}")
                    return None
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to get installment {installment_id} for user {user_id}: {e}")
            raise
    
    def get_installments_by_ids(self, installment_ids: List[str], user_id: str) -> List[Dict[str, Any]]:
        """
        Get multiple installments by IDs with client information
        
        Args:
            installment_ids: List of installment IDs
            user_id: User ID for authorization
            
        Returns:
            List of installment dictionaries with client information
        """
        if not installment_ids:
            return []
        
        # Build IN clause for the query
        id_params = {}
        id_placeholders = []
        
        for i, installment_id in enumerate(installment_ids):
            param_name = f'$id_{i}'
            id_params[param_name] = installment_id
            id_placeholders.append(param_name)
        
        # First try a simple query to check if installments exist at all (without user ID check)
        check_query = f"""
        {' '.join([f'DECLARE {param} AS Utf8;' for param in id_params.keys()])}
        
        SELECT 
            i.id as installment_id,
            i.user_id as owner_user_id
        FROM installments i
        WHERE i.id IN ({', '.join(id_placeholders)});
        """
        
        try:
            check_parameters = {}
            check_parameters.update(id_params)
            
            check_result_sets = self.db.execute_query(check_query, check_parameters)
            
            if check_result_sets and check_result_sets[0].rows:
                for row in check_result_sets[0].rows:
                    logger.info(f"Found installment {row.installment_id} owned by user {row.owner_user_id} (requesting user: {user_id})")
                    
                    # If the installment exists but belongs to a different user, this is a permission issue
                    if row.owner_user_id != user_id:
                        logger.warning(f"Permission denied: Installment {row.installment_id} belongs to user {row.owner_user_id}, not {user_id}")
            else:
                logger.warning(f"No installments found with IDs: {installment_ids}")
        
        except Exception as e:
            logger.error(f"Failed to check installment existence: {e}")
        
        # Now proceed with the regular query with user ID check
        query = f"""
        DECLARE $user_id AS Utf8;
        {' '.join([f'DECLARE {param} AS Utf8;' for param in id_params.keys()])}
        
        SELECT 
            i.id as installment_id,
            COALESCE(i.product_name, 'Unknown Product') as product_name,
            i.monthly_payment,
            i.installment_price as total_price,
            i.down_payment_date as installment_start_date,
            i.term_months,
            c.id as client_id,
            c.full_name as client_name,
            c.contact_number as client_phone
        FROM installments i
        JOIN clients c ON i.client_id = c.id
        WHERE i.id IN ({', '.join(id_placeholders)})
        AND i.user_id = $user_id
        AND c.user_id = $user_id;
        """
        
        try:
            parameters = {'$user_id': user_id}
            parameters.update(id_params)
            
            result_sets = self.db.execute_query(query, parameters)
            
            installments = []
            if result_sets and result_sets[0].rows:
                for row in result_sets[0].rows:
                    try:
                        # Safely access fields with default values if they're None
                        product_name = row.product_name if hasattr(row, 'product_name') and row.product_name is not None else 'Unknown Product'
                        monthly_payment = float(getattr(row, 'monthly_payment', 0) or 0)

                        total_price = float(row.total_price) if hasattr(row, 'total_price') and row.total_price is not None else 0.0
                        term_months = int(row.term_months) if hasattr(row, 'term_months') and row.term_months is not None else 0
                        
                        # Convert integer date to datetime object if needed
                        start_date = None
                        if hasattr(row, 'installment_start_date') and row.installment_start_date is not None:
                            start_date = row.installment_start_date
                            if isinstance(start_date, int):
                                # Convert timestamp to datetime
                                from datetime import datetime
                                start_date = datetime.fromtimestamp(start_date).date()
                        else:
                            # Use current date if start_date is None
                            from datetime import datetime
                            start_date = datetime.utcnow().date()
                        
                        current_date = datetime.utcnow().date()
                        
                        # Calculate months since start
                        months_since_start = (current_date.year - start_date.year) * 12 + (current_date.month - start_date.month)
                        
                        # Next payment date
                        next_payment_month = start_date.month + months_since_start + 1
                        next_payment_year = start_date.year + (next_payment_month - 1) // 12
                        next_payment_month = ((next_payment_month - 1) % 12) + 1
                        
                        try:
                            next_due_date = datetime(next_payment_year, next_payment_month, start_date.day).date()
                        except ValueError:
                            import calendar
                            last_day = calendar.monthrange(next_payment_year, next_payment_month)[1]
                            next_due_date = datetime(next_payment_year, next_payment_month, min(start_date.day, last_day)).date()
                        
                        days_remaining = (next_due_date - current_date).days
                        
                        installments.append({
                            'installment_id': row.installment_id,
                            'product_name': product_name,
                            'monthly_payment': monthly_payment,
                            'total_price': total_price,
                            'installment_start_date': start_date,
                            'term_months': term_months,
                            'client_id': row.client_id if hasattr(row, 'client_id') and row.client_id is not None else 'unknown',
                            'client_name': row.client_name if hasattr(row, 'client_name') and row.client_name is not None else 'Unknown Client',
                            'client_phone': row.client_phone if hasattr(row, 'client_phone') and row.client_phone is not None else 'No Phone',
                            'due_date': next_due_date,
                            'days_remaining': days_remaining
                        })
                    except Exception as e:
                        logger.error(f"Error processing installment row: {e}")
                        # Continue with next installment
                        continue
            
            logger.info(f"Found {len(installments)} installments for {len(installment_ids)} requested IDs")
            return installments
            
        except Exception as e:
            logger.error(f"Failed to get installments by IDs for user {user_id}: {e}")
            raise

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