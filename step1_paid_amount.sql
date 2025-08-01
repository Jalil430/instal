-- Update paid_amount
UPDATE installments SET
    paid_amount = (
        SELECT SUM(p.expected_amount)
        FROM installment_payments p 
        WHERE p.installment_id = installments.id AND p.is_paid = true
    );