#!/usr/bin/env python3
"""
Complete script to populate calculated fields for existing installments.
This script will:
1. Get client and investor names
2. Calculate payment amounts and status
3. Update all calculated fields in the installments table
"""

import os
import ydb
from datetime import datetime, date
from decimal import Decimal

def connect_to_ydb():
    """Connect to YDB database"""
    driver_config = ydb.DriverConfig(
        endpoint=os.environ.get('YDB_ENDPOINT'),
        database=os.environ.get('YDB_DATABASE'),
        credentials=ydb.iam.MetadataUrlCredentials()
    )
    driver = ydb.Driver(driver_config)
    driver.wait(fail_fast=True, timeout=10)
    return driver

def populate_calculated_fields():
    """Populate all calculated fields for existing installments"""
    driver = connect_to_ydb()
    pool = ydb.SessionPool(driver)
    
    def update_installments(session):
        # Get all installments that need updating
        get_installments_query = """
        SELECT 
            i.id,
            i.client_id,
            i.investor_id,
            i.installment_price,
            i.down_payment,
            i.down_payment_date,
            i.installment_start_date,
            i.term_months,
            i.monthly_payment,
            c.name as client_name,
            inv.name as investor_name
        FROM installments i
        LEFT JOIN clients c ON i.client_id = c.id
        LEFT JOIN investors inv ON i.investor_id = inv.id
        WHERE i.client_name IS NULL OR i.investor_name IS NULL 
           OR i.paid_amount IS NULL OR i.remaining_amount IS NULL
           OR i.payment_status IS NULL;
        """
        
        result = session.transaction(ydb.SerializableReadWrite()).execute(
            get_installments_query, commit_tx=True
        )
        
        installments_to_update = []
        for row in result[0].rows:
            installments_to_update.append({
                'id': row.id,
                'client_id': row.client_id,
                'investor_id': row.investor_id,
                'installment_price': float(row.installment_price),
                'down_payment': float(row.down_payment),
                'down_payment_date': row.down_payment_date,
                'installment_start_date': row.installment_start_date,
                'term_months': row.term_months,
                'monthly_payment': float(row.monthly_payment),
                'client_name': row.client_name or 'Unknown Client',
                'investor_name': row.investor_name or 'Unknown Investor'
            })
        
        print(f"Found {len(installments_to_update)} installments to update")
        
        # Update each installment
        for installment in installments_to_update:
            installment_id = installment['id']
            
            # Get payment information for this installment
            payments_query = """
            DECLARE $installment_id AS Utf8;
            SELECT 
                SUM(CASE WHEN is_paid = true THEN expected_amount ELSE 0 END) as paid_amount,
                COUNT(*) as total_payments,
                SUM(CASE WHEN is_paid = true THEN 1 ELSE 0 END) as paid_payments,
                SUM(CASE WHEN is_paid = false AND due_date < CurrentUtcDate() THEN 1 ELSE 0 END) as overdue_count,
                MIN(CASE WHEN is_paid = false THEN due_date ELSE NULL END) as next_payment_date,
                MIN(CASE WHEN is_paid = false THEN expected_amount ELSE NULL END) as next_payment_amount,
                MAX(CASE WHEN is_paid = true THEN paid_date ELSE NULL END) as last_payment_date
            FROM installment_payments
            WHERE installment_id = $installment_id;
            """
            
            payment_result = session.transaction(ydb.SerializableReadWrite()).execute(
                session.prepare(payments_query),
                {'$installment_id': installment_id},
                commit_tx=True
            )
            
            if payment_result[0].rows:
                payment_row = payment_result[0].rows[0]
                paid_amount = float(payment_row.paid_amount or 0)
                total_payments = payment_row.total_payments or 0
                paid_payments = payment_row.paid_payments or 0
                overdue_count = payment_row.overdue_count or 0
                next_payment_date = payment_row.next_payment_date
                next_payment_amount = float(payment_row.next_payment_amount or 0)
                last_payment_date = payment_row.last_payment_date
            else:
                # No payments found, set defaults
                paid_amount = 0.0
                total_payments = installment['term_months']
                paid_payments = 0
                overdue_count = 0
                next_payment_date = installment['down_payment_date'] if installment['down_payment'] > 0 else installment['installment_start_date']
                next_payment_amount = installment['down_payment'] if installment['down_payment'] > 0 else installment['monthly_payment']
                last_payment_date = None
            
            # Calculate remaining amount and payment status
            remaining_amount = installment['installment_price'] - paid_amount
            
            if remaining_amount <= 0:
                payment_status = 'оплачено'
            elif overdue_count > 0:
                payment_status = 'просрочено'
            elif next_payment_date and next_payment_date <= date.today():
                payment_status = 'к оплате'
            else:
                payment_status = 'предстоящий'
            
            # Update the installment with calculated fields
            update_query = """
            DECLARE $installment_id AS Utf8;
            DECLARE $client_name AS Utf8;
            DECLARE $investor_name AS Utf8;
            DECLARE $paid_amount AS Decimal(22,9);
            DECLARE $remaining_amount AS Decimal(22,9);
            DECLARE $next_payment_date AS Optional<Date>;
            DECLARE $next_payment_amount AS Decimal(22,9);
            DECLARE $payment_status AS Utf8;
            DECLARE $overdue_count AS Int32;
            DECLARE $total_payments AS Int32;
            DECLARE $paid_payments AS Int32;
            DECLARE $last_payment_date AS Optional<Date>;
            
            UPDATE installments SET
                client_name = $client_name,
                investor_name = $investor_name,
                paid_amount = $paid_amount,
                remaining_amount = $remaining_amount,
                next_payment_date = $next_payment_date,
                next_payment_amount = $next_payment_amount,
                payment_status = $payment_status,
                overdue_count = $overdue_count,
                total_payments = $total_payments,
                paid_payments = $paid_payments,
                last_payment_date = $last_payment_date,
                updated_at = CurrentUtcTimestamp()
            WHERE id = $installment_id;
            """
            
            session.transaction(ydb.SerializableReadWrite()).execute(
                session.prepare(update_query),
                {
                    '$installment_id': installment_id,
                    '$client_name': installment['client_name'],
                    '$investor_name': installment['investor_name'],
                    '$paid_amount': Decimal(str(paid_amount)),
                    '$remaining_amount': Decimal(str(remaining_amount)),
                    '$next_payment_date': next_payment_date,
                    '$next_payment_amount': Decimal(str(next_payment_amount)),
                    '$payment_status': payment_status,
                    '$overdue_count': overdue_count,
                    '$total_payments': total_payments,
                    '$paid_payments': paid_payments,
                    '$last_payment_date': last_payment_date
                },
                commit_tx=True
            )
            
            print(f"Updated installment {installment_id}: {payment_status}, paid: {paid_amount}, remaining: {remaining_amount}")
        
        print(f"Successfully updated {len(installments_to_update)} installments")
        return len(installments_to_update)
    
    try:
        updated_count = pool.retry_operation_sync(update_installments)
        print(f"Completed: Updated {updated_count} installments with calculated fields")
    finally:
        driver.stop()

if __name__ == "__main__":
    print("Starting calculated fields population...")
    populate_calculated_fields()
    print("Done!")