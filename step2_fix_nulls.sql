-- Set paid_amount to 0 where it's NULL (no payments made)
UPDATE installments SET paid_amount = CAST(0 AS Decimal(22,9)) WHERE paid_amount IS NULL;