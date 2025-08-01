-- =====================================================
-- STEP 1B: SET DEFAULT VALUES FOR NEW COLUMNS (YDB Compatible)
-- =====================================================

-- Set default values for numeric columns with proper YDB casting
UPDATE installments SET 
    paid_amount = CAST(0 AS Decimal(22,9))
WHERE paid_amount IS NULL;

UPDATE installments SET 
    remaining_amount = CAST(installment_price AS Decimal(22,9))
WHERE remaining_amount IS NULL;

UPDATE installments SET 
    next_payment_amount = CAST(0 AS Decimal(22,9))
WHERE next_payment_amount IS NULL;

UPDATE installments SET 
    payment_status = CAST('предстоящий' AS Utf8)
WHERE payment_status IS NULL;

UPDATE installments SET 
    overdue_count = CAST(0 AS Int32)
WHERE overdue_count IS NULL;

UPDATE installments SET 
    total_payments = CAST(0 AS Int32)
WHERE total_payments IS NULL;

UPDATE installments SET 
    paid_payments = CAST(0 AS Int32)
WHERE paid_payments IS NULL;