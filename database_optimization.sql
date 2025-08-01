-- =====================================================
-- DATABASE SCHEMA OPTIMIZATION FOR INSTAL APPLICATION
-- =====================================================

-- PART 1: ADD CALCULATED FIELDS TO INSTALLMENTS TABLE
-- These fields will be updated via triggers or application logic
-- to avoid N+1 query problems in the frontend

-- Add calculated payment summary fields
ALTER TABLE installments ADD COLUMN paid_amount Decimal(22,9) DEFAULT 0;
ALTER TABLE installments ADD COLUMN remaining_amount Decimal(22,9) DEFAULT 0;
ALTER TABLE installments ADD COLUMN next_payment_date Date;
ALTER TABLE installments ADD COLUMN next_payment_amount Decimal(22,9) DEFAULT 0;
ALTER TABLE installments ADD COLUMN payment_status Utf8 DEFAULT 'предстоящий'; -- 'просрочено', 'к оплате', 'предстоящий', 'оплачено'
ALTER TABLE installments ADD COLUMN overdue_count Int32 DEFAULT 0;
ALTER TABLE installments ADD COLUMN total_payments Int32 DEFAULT 0;
ALTER TABLE installments ADD COLUMN paid_payments Int32 DEFAULT 0;
ALTER TABLE installments ADD COLUMN last_payment_date Date;

-- Add denormalized client/investor names for faster display
ALTER TABLE installments ADD COLUMN client_name Utf8;
ALTER TABLE installments ADD COLUMN investor_name Utf8;

-- PART 2: ESSENTIAL DATABASE INDEXES
-- These dramatically improve query performance by creating shortcuts to data

-- What are indexes?
-- Indexes are like a book's index - they help find data quickly without scanning every row
-- Example: Finding user's installments without index = scan 100,000 rows
--          Finding user's installments with index = jump to 50 relevant rows instantly

-- 1. Primary indexes for installments table
CREATE INDEX idx_installments_user_created ON installments (user_id, created_at DESC);
CREATE INDEX idx_installments_user_status ON installments (user_id, payment_status);
CREATE INDEX idx_installments_user_client ON installments (user_id, client_id);
CREATE INDEX idx_installments_user_investor ON installments (user_id, investor_id);

-- 2. Primary indexes for installment_payments table  
CREATE INDEX idx_installment_payments_installment ON installment_payments (installment_id);
CREATE INDEX idx_installment_payments_due_date ON installment_payments (due_date);
CREATE INDEX idx_installment_payments_status_date ON installment_payments (is_paid, due_date);

-- 3. Composite indexes for complex queries (multiple columns)
CREATE INDEX idx_payments_installment_status_date ON installment_payments (installment_id, is_paid, due_date);
CREATE INDEX idx_payments_installment_paid ON installment_payments (installment_id, is_paid);

-- 4. Indexes for clients and investors (for JOIN operations)
CREATE INDEX idx_clients_user_id ON clients (user_id);
CREATE INDEX idx_investors_user_id ON investors (user_id);

-- 5. Search indexes (for text search functionality)
CREATE INDEX idx_clients_search ON clients (user_id, full_name);
CREATE INDEX idx_installments_search ON installments (user_id, product_name);

-- 6. Analytics indexes (for dashboard and reporting)
CREATE INDEX idx_installments_analytics ON installments (user_id, payment_status, installment_price);
CREATE INDEX idx_payments_analytics ON installment_payments (due_date, is_paid);
CREATE INDEX idx_payments_paid_date ON installment_payments (paid_date, is_paid) WHERE is_paid = true;
CREATE INDEX idx_installments_created_date ON installments (created_at, user_id);

-- PART 3: ANALYTICS-SPECIFIC OPTIMIZATIONS
-- Using optimized queries instead of summary tables for better real-time accuracy

-- PART 4: STORED PROCEDURES FOR MAINTAINING CALCULATED FIELDS
-- These procedures should be called when payments are updated

-- Procedure to update installment calculated fields
-- Call this whenever a payment is updated for an installment
/*
CREATE OR REPLACE PROCEDURE UpdateInstallmentCalculatedFields(installment_id_param Utf8)
AS
BEGIN
    DECLARE paid_amount_calc Decimal(22,9);
    DECLARE remaining_amount_calc Decimal(22,9);
    DECLARE next_payment_date_calc Date;
    DECLARE next_payment_amount_calc Decimal(22,9);
    DECLARE payment_status_calc Utf8;
    DECLARE overdue_count_calc Int32;
    DECLARE total_payments_calc Int32;
    DECLARE paid_payments_calc Int32;
    DECLARE last_payment_date_calc Date;
    DECLARE client_name_calc Utf8;
    DECLARE investor_name_calc Utf8;
    
    -- Calculate payment summary
    SELECT 
        COALESCE(SUM(CASE WHEN is_paid = true THEN expected_amount ELSE 0 END), 0),
        COUNT(*),
        COUNT(CASE WHEN is_paid = true THEN 1 END),
        COUNT(CASE WHEN is_paid = false AND due_date < CurrentUtcDate() THEN 1 END),
        MIN(CASE WHEN is_paid = false THEN due_date END),
        MIN(CASE WHEN is_paid = false THEN expected_amount END),
        MAX(CASE WHEN is_paid = true THEN paid_date END)
    INTO paid_amount_calc, total_payments_calc, paid_payments_calc, overdue_count_calc, 
         next_payment_date_calc, next_payment_amount_calc, last_payment_date_calc
    FROM installment_payments 
    WHERE installment_id = installment_id_param;
    
    -- Get installment price for remaining amount calculation
    SELECT installment_price INTO remaining_amount_calc
    FROM installments 
    WHERE id = installment_id_param;
    
    SET remaining_amount_calc = remaining_amount_calc - paid_amount_calc;
    
    -- Calculate payment status
    IF overdue_count_calc > 0 THEN
        SET payment_status_calc = 'просрочено';
    ELSEIF paid_payments_calc = total_payments_calc AND total_payments_calc > 0 THEN
        SET payment_status_calc = 'оплачено';
    ELSEIF next_payment_date_calc IS NOT NULL AND next_payment_date_calc <= CurrentUtcDate() THEN
        SET payment_status_calc = 'к оплате';
    ELSE
        SET payment_status_calc = 'предстоящий';
    END IF;
    
    -- Get client and investor names
    SELECT c.full_name, inv.full_name
    INTO client_name_calc, investor_name_calc
    FROM installments i
    LEFT JOIN clients c ON i.client_id = c.id
    LEFT JOIN investors inv ON i.investor_id = inv.id
    WHERE i.id = installment_id_param;
    
    -- Update installments table
    UPDATE installments SET
        paid_amount = paid_amount_calc,
        remaining_amount = remaining_amount_calc,
        next_payment_date = next_payment_date_calc,
        next_payment_amount = COALESCE(next_payment_amount_calc, 0),
        payment_status = payment_status_calc,
        overdue_count = overdue_count_calc,
        total_payments = total_payments_calc,
        paid_payments = paid_payments_calc,
        last_payment_date = last_payment_date_calc,
        client_name = client_name_calc,
        investor_name = investor_name_calc,
        updated_at = CurrentUtcTimestamp()
    WHERE id = installment_id_param;
END;
*/

-- PART 5: PERFORMANCE TESTING QUERIES
-- Use these to verify the indexes are working correctly

-- Test 1: Optimized installments list (should be VERY fast with new fields)
/*
SELECT 
    id, user_id, client_id, investor_id, product_name,
    cash_price, installment_price, down_payment, term_months, monthly_payment,
    down_payment_date, installment_start_date, installment_end_date,
    created_at, updated_at,
    -- Pre-calculated fields (no JOINs or aggregations needed!)
    client_name, investor_name,
    paid_amount, remaining_amount, next_payment_date, next_payment_amount,
    payment_status, overdue_count, total_payments, paid_payments, last_payment_date
FROM installments 
WHERE user_id = 'test-user-id'
ORDER BY created_at DESC
LIMIT 50;
*/

-- Test 2: Analytics dashboard (should be fast with optimized query and pre-calculated fields)
/*
SELECT 
    COUNT(DISTINCT CASE WHEN payment_status = 'просрочено' THEN id END) as overdue_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'к оплате' THEN id END) as due_today_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'предстоящий' THEN id END) as upcoming_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'оплачено' THEN id END) as paid_count,
    AVG(installment_price) as avg_installment_value,
    SUM(installment_price) as total_installment_value
FROM installments 
WHERE user_id = 'test-user-id';
*/

-- Test 3: Search installments (should be fast with indexes)
/*
SELECT id, product_name, client_name, payment_status, paid_amount, remaining_amount
FROM installments 
WHERE user_id = 'test-user-id' 
  AND (product_name LIKE '%search_term%' OR client_name LIKE '%search_term%')
ORDER BY created_at DESC;
*/

-- Test 4: Overdue installments (should be fast with status field)
/*
SELECT id, product_name, client_name, overdue_count, remaining_amount
FROM installments 
WHERE user_id = 'test-user-id' 
  AND payment_status = 'просрочено'
ORDER BY overdue_count DESC, next_payment_date ASC;
*/

-- PART 6: MIGRATION SCRIPT TO POPULATE CALCULATED FIELDS
-- Run this ONCE after adding the new columns to populate existing data

/*
-- Update all existing installments with calculated fields
UPDATE installments SET
    paid_amount = (
        SELECT COALESCE(SUM(CASE WHEN p.is_paid = true THEN p.expected_amount ELSE 0 END), 0)
        FROM installment_payments p 
        WHERE p.installment_id = installments.id
    ),
    remaining_amount = installments.installment_price - (
        SELECT COALESCE(SUM(CASE WHEN p.is_paid = true THEN p.expected_amount ELSE 0 END), 0)
        FROM installment_payments p 
        WHERE p.installment_id = installments.id
    ),
    total_payments = (
        SELECT COUNT(*) FROM installment_payments p WHERE p.installment_id = installments.id
    ),
    paid_payments = (
        SELECT COUNT(*) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = true
    ),
    overdue_count = (
        SELECT COUNT(*) FROM installment_payments p 
        WHERE p.installment_id = installments.id AND p.is_paid = false AND p.due_date < CurrentUtcDate()
    ),
    next_payment_date = (
        SELECT MIN(p.due_date) FROM installment_payments p 
        WHERE p.installment_id = installments.id AND p.is_paid = false
    ),
    next_payment_amount = (
        SELECT MIN(p.expected_amount) FROM installment_payments p 
        WHERE p.installment_id = installments.id AND p.is_paid = false
    ),
    last_payment_date = (
        SELECT MAX(p.paid_date) FROM installment_payments p 
        WHERE p.installment_id = installments.id AND p.is_paid = true
    ),
    client_name = (
        SELECT c.full_name FROM clients c WHERE c.id = installments.client_id
    ),
    investor_name = (
        SELECT inv.full_name FROM investors inv WHERE inv.id = installments.investor_id
    );

-- Update payment status based on calculated fields
UPDATE installments SET
    payment_status = CASE
        WHEN overdue_count > 0 THEN 'просрочено'
        WHEN paid_payments = total_payments AND total_payments > 0 THEN 'оплачено'
        WHEN next_payment_date IS NOT NULL AND next_payment_date <= CurrentUtcDate() THEN 'к оплате'
        ELSE 'предстоящий'
    END;
*/