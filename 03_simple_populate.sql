-- =====================================================
-- RUN EACH STATEMENT ONE BY ONE IN YDB CONSOLE
-- =====================================================

-- 1. Update paid_amount
UPDATE installments SET paid_amount = (SELECT SUM(p.expected_amount) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = true);

-- 2. Fix NULL paid_amount
UPDATE installments SET paid_amount = CAST(0 AS Decimal(22,9)) WHERE paid_amount IS NULL;

-- 3. Update remaining_amount  
UPDATE installments SET remaining_amount = installments.installment_price - COALESCE(paid_amount, CAST(0 AS Decimal(22,9)));

-- 4. Update total_payments
UPDATE installments SET total_payments = (SELECT COUNT(*) FROM installment_payments p WHERE p.installment_id = installments.id);

-- 5. Update paid_payments
UPDATE installments SET paid_payments = (SELECT COUNT(*) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = true);

-- 6. Update overdue_count
UPDATE installments SET overdue_count = (SELECT COUNT(*) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = false AND p.due_date < CurrentUtcDate());

-- 7. Update next_payment_date
UPDATE installments SET next_payment_date = (SELECT MIN(p.due_date) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = false);

-- 8. Update next_payment_amount
UPDATE installments SET next_payment_amount = (SELECT MIN(p.expected_amount) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = false);

-- 9. Fix NULL next_payment_amount
UPDATE installments SET next_payment_amount = CAST(0 AS Decimal(22,9)) WHERE next_payment_amount IS NULL;

-- 10. Update last_payment_date
UPDATE installments SET last_payment_date = (SELECT MAX(p.paid_date) FROM installment_payments p WHERE p.installment_id = installments.id AND p.is_paid = true);

-- 11. Update client_name
UPDATE installments SET client_name = (SELECT c.full_name FROM clients c WHERE c.id = installments.client_id) WHERE client_name IS NULL;

-- 12. Update investor_name
UPDATE installments SET investor_name = (SELECT inv.full_name FROM investors inv WHERE inv.id = installments.investor_id) WHERE investor_name IS NULL;

-- 13. Update payment status
UPDATE installments SET payment_status = CASE WHEN overdue_count > 0 THEN 'просрочено' WHEN paid_payments = total_payments AND total_payments > 0 THEN 'оплачено' WHEN next_payment_date IS NOT NULL AND next_payment_date <= CurrentUtcDate() THEN 'к оплате' ELSE 'предстоящий' END;