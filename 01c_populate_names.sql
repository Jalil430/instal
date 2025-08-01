-- =====================================================
-- POPULATE CLIENT AND INVESTOR NAMES
-- =====================================================

-- Update client names
UPDATE installments SET 
    client_name = (
        SELECT c.full_name 
        FROM clients c 
        WHERE c.id = installments.client_id
    )
WHERE client_name IS NULL;

-- Update investor names  
UPDATE installments SET 
    investor_name = (
        SELECT inv.full_name 
        FROM investors inv 
        WHERE inv.id = installments.investor_id
    )
WHERE investor_name IS NULL;