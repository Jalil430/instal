-- =====================================================
-- STEP 4: PERFORMANCE TESTING QUERIES
-- =====================================================

-- Test 1: Optimized installments list (should be VERY fast with new fields)
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

-- Test 2: Analytics dashboard (should be fast with pre-calculated fields)
SELECT 
    COUNT(DISTINCT CASE WHEN payment_status = 'просрочено' THEN id END) as overdue_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'к оплате' THEN id END) as due_today_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'предстоящий' THEN id END) as upcoming_count,
    COUNT(DISTINCT CASE WHEN payment_status = 'оплачено' THEN id END) as paid_count,
    AVG(installment_price) as avg_installment_value,
    SUM(installment_price) as total_installment_value
FROM installments 
WHERE user_id = 'test-user-id';

-- Test 3: Search installments (should be fast with indexes)
SELECT id, product_name, client_name, payment_status, paid_amount, remaining_amount
FROM installments 
WHERE user_id = 'test-user-id' 
  AND (product_name LIKE '%search_term%' OR client_name LIKE '%search_term%')
ORDER BY created_at DESC;

-- Test 4: Overdue installments (should be fast with status field)
SELECT id, product_name, client_name, overdue_count, remaining_amount
FROM installments 
WHERE user_id = 'test-user-id' 
  AND payment_status = 'просрочено'
ORDER BY overdue_count DESC, next_payment_date ASC;