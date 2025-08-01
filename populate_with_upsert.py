#!/usr/bin/env python3
"""
YDB Calculated Fields Population using UPSERT
This script uses UPSERT statements to populate calculated fields
"""

import os
import ydb

# YDB connection configuration
YDB_ENDPOINT = os.getenv('YDB_ENDPOINT')
YDB_DATABASE = os.getenv('YDB_DATABASE')

def get_ydb_driver():
    """Create YDB driver instance"""
    return ydb.Driver(
        endpoint=YDB_ENDPOINT,
        database=YDB_DATABASE,
        credentials=ydb.credentials_from_env_variables()
    )

def execute_upsert_statements():
    """Execute UPSERT statements to populate calculated fields"""
    
    driver = get_ydb_driver()
    
    upsert_statements = [
        # 1. Update paid_amount
        """
        UPSERT INTO installments (id, paid_amount)
        SELECT 
            i.id,
            COALESCE((
                SELECT SUM(p.expected_amount)
                FROM installment_payments p 
                WHERE p.installment_id = i.id AND p.is_paid = true
            ), 0.0) AS paid_amount
        FROM installments i
        """,
        
        # 2. Update remaining_amount
        """
        UPSERT INTO installments (id, remaining_amount)
        SELECT 
            i.id,
            i.installment_price - COALESCE(i.paid_amount, 0.0) AS remaining_amount
        FROM installments i
        """,
        
        # 3. Update total_payments
        """
        UPSERT INTO installments (id, total_payments)
        SELECT 
            i.id,
            COALESCE((
                SELECT COUNT(*)
                FROM installment_payments p 
                WHERE p.installment_id = i.id
            ), 0) AS total_payments
        FROM installments i
        """,
        
        # 4. Update paid_payments
        """
        UPSERT INTO installments (id, paid_payments)
        SELECT 
            i.id,
            COALESCE((
                SELECT COUNT(*)
                FROM installment_payments p 
                WHERE p.installment_id = i.id AND p.is_paid = true
            ), 0) AS paid_payments
        FROM installments i
        """,
        
        # 5. Update overdue_count
        """
        UPSERT INTO installments (id, overdue_count)
        SELECT 
            i.id,
            COALESCE((
                SELECT COUNT(*)
                FROM installment_payments p 
                WHERE p.installment_id = i.id 
                  AND p.is_paid = false 
                  AND p.due_date < CurrentUtcDate()
            ), 0) AS overdue_count
        FROM installments i
        """,
        
        # 6. Update next_payment_date
        """
        UPSERT INTO installments (id, next_payment_date)
        SELECT 
            i.id,
            (SELECT MIN(p.due_date)
             FROM installment_payments p 
             WHERE p.installment_id = i.id AND p.is_paid = false) AS next_payment_date
        FROM installments i
        """,
        
        # 7. Update next_payment_amount
        """
        UPSERT INTO installments (id, next_payment_amount)
        SELECT 
            i.id,
            COALESCE((
                SELECT MIN(p.expected_amount)
                FROM installment_payments p 
                WHERE p.installment_id = i.id AND p.is_paid = false
            ), 0.0) AS next_payment_amount
        FROM installments i
        """,
        
        # 8. Update last_payment_date
        """
        UPSERT INTO installments (id, last_payment_date)
        SELECT 
            i.id,
            (SELECT MAX(p.paid_date)
             FROM installment_payments p 
             WHERE p.installment_id = i.id AND p.is_paid = true) AS last_payment_date
        FROM installments i
        """,
        
        # 9. Update client_name
        """
        UPSERT INTO installments (id, client_name)
        SELECT 
            i.id,
            COALESCE(c.full_name, '') AS client_name
        FROM installments i
        LEFT JOIN clients c ON c.id = i.client_id
        """,
        
        # 10. Update investor_name
        """
        UPSERT INTO installments (id, investor_name)
        SELECT 
            i.id,
            COALESCE(inv.full_name, '') AS investor_name
        FROM installments i
        LEFT JOIN investors inv ON inv.id = i.investor_id
        """,
        
        # 11. Update payment_status
        """
        UPSERT INTO installments (id, payment_status)
        SELECT 
            i.id,
            CASE 
                WHEN i.overdue_count > 0 THEN 'просрочено'
                WHEN i.paid_payments = i.total_payments AND i.total_payments > 0 THEN 'оплачено'
                WHEN i.next_payment_date IS NOT NULL AND i.next_payment_date <= CurrentUtcDate() THEN 'к оплате'
                ELSE 'предстоящий'
            END AS payment_status
        FROM installments i
        """
    ]
    
    try:
        with ydb.SessionPool(driver) as pool:
            
            for i, statement in enumerate(upsert_statements, 1):
                print(f"Executing statement {i}/{len(upsert_statements)}...")
                
                def execute_statement(session):
                    session.transaction().execute(
                        statement,
                        commit_tx=True
                    )
                
                pool.retry_operation_sync(execute_statement)
                print(f"Statement {i} completed successfully")
            
            print("All calculated fields populated successfully!")
            
    except Exception as e:
        print(f"Error executing statement {i}: {e}")
        raise
    
    finally:
        driver.stop()

if __name__ == "__main__":
    print("Starting YDB calculated fields population with UPSERT...")
    execute_upsert_statements()
    print("Done!")