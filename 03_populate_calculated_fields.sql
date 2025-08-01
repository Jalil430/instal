-- =====================================================
-- STEP 3: POPULATE CALCULATED FIELDS FOR EXISTING DATA
-- =====================================================

-- Update all existing installments with calculated fields
UPDATE installments SET
    paid_amount = (
        SELECT COALESCE(SUM(CASE WHEN p.is_paid = true THEN p.expected_amount ELSE CAST(0 AS Decimal(22,9)) END), CAST(0 AS Decimal(22,9)))
        FROM installment_payments p 
        WHERE p.installment_id = installments.id
    ),
    remaining_amount = installments.installment_price - (
        SELECT COALESCE(SUM(CASE WHEN p.is_paid = true THEN p.expected_amount ELSE CAST(0 AS Decimal(22,9)) END), CAST(0 AS Decimal(22,9)))
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