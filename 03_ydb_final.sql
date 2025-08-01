-- =====================================================
-- YDB FINAL VERSION - Based on YDB Documentation
-- RUN EACH STATEMENT ONE BY ONE
-- =====================================================

-- 1. Update paid_amount using REPLACE INTO (YDB preferred method)
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    COALESCE((
        SELECT SUM(p.expected_amount)
        FROM installment_payments p 
        WHERE p.installment_id = i.id AND p.is_paid = true
    ), 0.0) AS paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 2. Update remaining_amount
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.installment_price - COALESCE(i.paid_amount, 0.0) AS remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 3. Update total_payments
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    COALESCE((
        SELECT COUNT(*)
        FROM installment_payments p 
        WHERE p.installment_id = i.id
    ), 0) AS total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 4. Update paid_payments
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    COALESCE((
        SELECT COUNT(*)
        FROM installment_payments p 
        WHERE p.installment_id = i.id AND p.is_paid = true
    ), 0) AS paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 5. Update overdue_count
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    COALESCE((
        SELECT COUNT(*)
        FROM installment_payments p 
        WHERE p.installment_id = i.id 
          AND p.is_paid = false 
          AND p.due_date < CurrentUtcDate()
    ), 0) AS overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 6. Update next_payment_date
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    (SELECT MIN(p.due_date)
     FROM installment_payments p 
     WHERE p.installment_id = i.id AND p.is_paid = false) AS next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 7. Update next_payment_amount
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    COALESCE((
        SELECT MIN(p.expected_amount)
        FROM installment_payments p 
        WHERE p.installment_id = i.id AND p.is_paid = false
    ), 0.0) AS next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 8. Update last_payment_date
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    (SELECT MAX(p.paid_date)
     FROM installment_payments p 
     WHERE p.installment_id = i.id AND p.is_paid = true) AS last_payment_date,
    i.client_name,
    i.investor_name,
    i.payment_status
FROM installments i;

-- 9. Update client_name
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    COALESCE(c.full_name, i.client_name) AS client_name,
    i.investor_name,
    i.payment_status
FROM installments i
LEFT JOIN clients c ON c.id = i.client_id;

-- 10. Update investor_name
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    COALESCE(inv.full_name, i.investor_name) AS investor_name,
    i.payment_status
FROM installments i
LEFT JOIN investors inv ON inv.id = i.investor_id;

-- 11. Update payment_status
REPLACE INTO installments
SELECT 
    i.id,
    i.client_id,
    i.investor_id,
    i.installment_price,
    i.installment_count,
    i.created_at,
    i.updated_at,
    i.paid_amount,
    i.remaining_amount,
    i.total_payments,
    i.paid_payments,
    i.overdue_count,
    i.next_payment_date,
    i.next_payment_amount,
    i.last_payment_date,
    i.client_name,
    i.investor_name,
    CASE 
        WHEN i.overdue_count > 0 THEN 'просрочено'
        WHEN i.paid_payments = i.total_payments AND i.total_payments > 0 THEN 'оплачено'
        WHEN i.next_payment_date IS NOT NULL AND i.next_payment_date <= CurrentUtcDate() THEN 'к оплате'
        ELSE 'предстоящий'
    END AS payment_status
FROM installments i;