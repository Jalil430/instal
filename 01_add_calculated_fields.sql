-- =====================================================
-- STEP 1: ADD CALCULATED FIELDS TO INSTALLMENTS TABLE
-- =====================================================

-- Add calculated payment summary fields (YDB compatible syntax)
ALTER TABLE installments ADD COLUMN paid_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN remaining_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN next_payment_date Date;
ALTER TABLE installments ADD COLUMN next_payment_amount Decimal(22,9);
ALTER TABLE installments ADD COLUMN payment_status Utf8;
ALTER TABLE installments ADD COLUMN overdue_count Int32;
ALTER TABLE installments ADD COLUMN total_payments Int32;
ALTER TABLE installments ADD COLUMN paid_payments Int32;
ALTER TABLE installments ADD COLUMN last_payment_date Date;

-- Add denormalized client/investor names for faster display
ALTER TABLE installments ADD COLUMN client_name Utf8;
ALTER TABLE installments ADD COLUMN investor_name Utf8;