-- =====================================================
-- SIMPLE APPROACH: ADD COLUMNS AND POPULATE IN ONE GO
-- =====================================================

-- First, add the columns (run this first)
ALTER TABLE installments ADD COLUMN paid_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN remaining_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN next_payment_date Date;
ALTER TABLE installments ADD COLUMN next_payment_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN payment_status Utf8;
ALTER TABLE installments ADD COLUMN overdue_count Int32;
ALTER TABLE installments ADD COLUMN total_payments Int32;
ALTER TABLE installments ADD COLUMN paid_payments Int32;
ALTER TABLE installments ADD COLUMN last_payment_date Date;
ALTER TABLE installments ADD COLUMN client_name Utf8;
ALTER TABLE installments ADD COLUMN investor_name Utf8;