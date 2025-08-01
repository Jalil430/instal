-- =====================================================
-- ULTRA SIMPLE YDB VERSION - RUN ONE BY ONE
-- =====================================================

-- 1. Update paid_amount (simple version)
UPSERT INTO installments (id, paid_amount)
SELECT 
    i.id,
    0.0 AS paid_amount
FROM installments AS i;

-- 2. Update remaining_amount  
UPSERT INTO installments (id, remaining_amount)
SELECT 
    i.id,
    i.installment_price AS remaining_amount
FROM installments AS i;

-- 3. Update total_payments
UPSERT INTO installments (id, total_payments)
SELECT 
    i.id,
    0 AS total_payments
FROM installments AS i;

-- 4. Update paid_payments
UPSERT INTO installments (id, paid_payments)
SELECT 
    i.id,
    0 AS paid_payments
FROM installments AS i;

-- 5. Update overdue_count
UPSERT INTO installments (id, overdue_count)
SELECT 
    i.id,
    0 AS overdue_count
FROM installments AS i;

-- 6. Update next_payment_date
UPSERT INTO installments (id, next_payment_date)
SELECT 
    i.id,
    NULL AS next_payment_date
FROM installments AS i;

-- 7. Update next_payment_amount
UPSERT INTO installments (id, next_payment_amount)
SELECT 
    i.id,
    0.0 AS next_payment_amount
FROM installments AS i;

-- 8. Update last_payment_date
UPSERT INTO installments (id, last_payment_date)
SELECT 
    i.id,
    NULL AS last_payment_date
FROM installments AS i;

-- 9. Update client_name
UPSERT INTO installments (id, client_name)
SELECT 
    i.id,
    c.full_name AS client_name
FROM installments AS i
JOIN clients AS c ON c.id = i.client_id;

-- 10. Update investor_name
UPSERT INTO installments (id, investor_name)
SELECT 
    i.id,
    inv.full_name AS investor_name
FROM installments AS i
JOIN investors AS inv ON inv.id = i.investor_id;

-- 11. Update payment_status
UPSERT INTO installments (id, payment_status)
SELECT 
    i.id,
    'предстоящий' AS payment_status
FROM installments AS i;