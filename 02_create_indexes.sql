-- =====================================================
-- STEP 2: CREATE ESSENTIAL DATABASE INDEXES FOR YDB
-- =====================================================
-- NOTE: YDB uses different syntax for secondary indexes
-- Run each ALTER TABLE statement separately

-- 1. Primary indexes for installments table
ALTER TABLE installments ADD INDEX idx_installments_user_created GLOBAL ON (user_id, created_at);
ALTER TABLE installments ADD INDEX idx_installments_user_status GLOBAL ON (user_id, payment_status);
ALTER TABLE installments ADD INDEX idx_installments_user_client GLOBAL ON (user_id, client_id);
ALTER TABLE installments ADD INDEX idx_installments_user_investor GLOBAL ON (user_id, investor_id);

-- 2. Primary indexes for installment_payments table  
ALTER TABLE installment_payments ADD INDEX idx_installment_payments_installment GLOBAL ON (installment_id);
ALTER TABLE installment_payments ADD INDEX idx_installment_payments_due_date GLOBAL ON (due_date);
ALTER TABLE installment_payments ADD INDEX idx_installment_payments_status_date GLOBAL ON (is_paid, due_date);

-- 3. Composite indexes for complex queries
ALTER TABLE installment_payments ADD INDEX idx_payments_installment_status_date GLOBAL ON (installment_id, is_paid, due_date);
ALTER TABLE installment_payments ADD INDEX idx_payments_installment_paid GLOBAL ON (installment_id, is_paid);

-- 4. Indexes for clients and investors (for JOIN operations)
ALTER TABLE clients ADD INDEX idx_clients_user_id GLOBAL ON (user_id);
ALTER TABLE investors ADD INDEX idx_investors_user_id GLOBAL ON (user_id);

-- 5. Search indexes (for text search functionality)
ALTER TABLE clients ADD INDEX idx_clients_search GLOBAL ON (user_id, full_name);
ALTER TABLE installments ADD INDEX idx_installments_search GLOBAL ON (user_id, product_name);

-- 6. Analytics indexes (for dashboard and reporting)
ALTER TABLE installments ADD INDEX idx_installments_analytics GLOBAL ON (user_id, payment_status, installment_price);
ALTER TABLE installment_payments ADD INDEX idx_payments_analytics GLOBAL ON (due_date, is_paid);
ALTER TABLE installment_payments ADD INDEX idx_payments_paid_date GLOBAL ON (paid_date, is_paid);
ALTER TABLE installments ADD INDEX idx_installments_created_date GLOBAL ON (created_at, user_id);