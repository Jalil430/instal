#!/usr/bin/env python3
"""
YDB Calculated Fields Population Script
This script populates the calculated fields in the installments table
using the YDB Python SDK instead of complex SQL statements.
"""

import os
import ydb
from datetime import datetime

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

def populate_calculated_fields():
    """Populate all calculated fields in installments table"""
    
    driver = get_ydb_driver()
    
    try:
        with ydb.SessionPool(driver) as pool:
            
            # Step 1: Get all installments
            print("Step 1: Fetching all installments...")
            installments_query = """
                SELECT id, client_id, investor_id, installment_price
                FROM installments
            """
            
            installments = []
            def fetch_installments(session):
                result_sets = session.transaction().execute(
                    installments_query,
                    commit_tx=True
                )
                for row in result_sets[0].rows:
                    installments.append({
                        'id': row.id,
                        'client_id': row.client_id,
                        'investor_id': row.investor_id,
                        'installment_price': float(row.installment_price)
                    })
            
            pool.retry_operation_sync(fetch_installments)
            print(f"Found {len(installments)} installments")
            
            # Step 2: Get payment data for each installment
            print("Step 2: Calculating payment data...")
            
            for installment in installments:
                installment_id = installment['id']
                
                # Get payment statistics
                payment_stats_query = f"""
                    SELECT 
                        COUNT(*) as total_payments,
                        SUM(CASE WHEN is_paid = true THEN 1 ELSE 0 END) as paid_payments,
                        SUM(CASE WHEN is_paid = true THEN expected_amount ELSE 0 END) as paid_amount,
                        SUM(CASE WHEN is_paid = false AND due_date < CurrentUtcDate() THEN 1 ELSE 0 END) as overdue_count,
                        MIN(CASE WHEN is_paid = false THEN due_date ELSE NULL END) as next_payment_date,
                        MIN(CASE WHEN is_paid = false THEN expected_amount ELSE NULL END) as next_payment_amount,
                        MAX(CASE WHEN is_paid = true THEN paid_date ELSE NULL END) as last_payment_date
                    FROM installment_payments 
                    WHERE installment_id = '{installment_id}'
                """
                
                def get_payment_stats(session):
                    result_sets = session.transaction().execute(
                        payment_stats_query,
                        commit_tx=True
                    )
                    if result_sets[0].rows:
                        row = result_sets[0].rows[0]
                        installment.update({
                            'total_payments': int(row.total_payments or 0),
                            'paid_payments': int(row.paid_payments or 0),
                            'paid_amount': float(row.paid_amount or 0.0),
                            'overdue_count': int(row.overdue_count or 0),
                            'next_payment_date': row.next_payment_date,
                            'next_payment_amount': float(row.next_payment_amount or 0.0),
                            'last_payment_date': row.last_payment_date
                        })
                
                pool.retry_operation_sync(get_payment_stats)
                
                # Calculate remaining amount
                installment['remaining_amount'] = installment['installment_price'] - installment['paid_amount']
                
                # Calculate payment status
                if installment['overdue_count'] > 0:
                    installment['payment_status'] = 'просрочено'
                elif installment['paid_payments'] == installment['total_payments'] and installment['total_payments'] > 0:
                    installment['payment_status'] = 'оплачено'
                elif installment['next_payment_date'] and installment['next_payment_date'] <= datetime.now().date():
                    installment['payment_status'] = 'к оплате'
                else:
                    installment['payment_status'] = 'предстоящий'
            
            # Step 3: Get client and investor names
            print("Step 3: Fetching client and investor names...")
            
            # Get all clients
            clients_query = "SELECT id, full_name FROM clients"
            clients = {}
            
            def fetch_clients(session):
                result_sets = session.transaction().execute(
                    clients_query,
                    commit_tx=True
                )
                for row in result_sets[0].rows:
                    clients[row.id] = row.full_name
            
            pool.retry_operation_sync(fetch_clients)
            
            # Get all investors
            investors_query = "SELECT id, full_name FROM investors"
            investors = {}
            
            def fetch_investors(session):
                result_sets = session.transaction().execute(
                    investors_query,
                    commit_tx=True
                )
                for row in result_sets[0].rows:
                    investors[row.id] = row.full_name
            
            pool.retry_operation_sync(fetch_investors)
            
            # Add names to installments
            for installment in installments:
                installment['client_name'] = clients.get(installment['client_id'], '')
                installment['investor_name'] = investors.get(installment['investor_id'], '')
            
            # Step 4: Update installments with calculated fields
            print("Step 4: Updating installments with calculated fields...")
            
            def update_installment(session, installment):
                update_query = f"""
                    UPDATE installments 
                    SET 
                        paid_amount = {installment['paid_amount']},
                        remaining_amount = {installment['remaining_amount']},
                        total_payments = {installment['total_payments']},
                        paid_payments = {installment['paid_payments']},
                        overdue_count = {installment['overdue_count']},
                        next_payment_date = {"'" + str(installment['next_payment_date']) + "'" if installment['next_payment_date'] else 'NULL'},
                        next_payment_amount = {installment['next_payment_amount']},
                        last_payment_date = {"'" + str(installment['last_payment_date']) + "'" if installment['last_payment_date'] else 'NULL'},
                        client_name = '{installment['client_name']}',
                        investor_name = '{installment['investor_name']}',
                        payment_status = '{installment['payment_status']}'
                    WHERE id = '{installment['id']}'
                """
                
                session.transaction().execute(
                    update_query,
                    commit_tx=True
                )
            
            # Update in batches
            for i, installment in enumerate(installments):
                pool.retry_operation_sync(lambda session: update_installment(session, installment))
                if (i + 1) % 10 == 0:
                    print(f"Updated {i + 1}/{len(installments)} installments")
            
            print(f"Successfully updated all {len(installments)} installments!")
            
    except Exception as e:
        print(f"Error: {e}")
        raise
    
    finally:
        driver.stop()

if __name__ == "__main__":
    print("Starting YDB calculated fields population...")
    populate_calculated_fields()
    print("Done!")