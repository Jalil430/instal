# Migration Export Verification

Use this checklist after deploying `export-migration` and updating `instal-api.yaml`.

## 1) Functional check

1. Log in as test user A.
2. Open **Settings -> Export for FinPay CRM**.
3. Confirm file downloads as `finpay-legacy-export-YYYY-MM-DD.json`.
4. Open file and confirm top-level keys:
   - `clients`
   - `installments`
   - `payments`

## 2) Tenant isolation check

1. Export file as user A.
2. Log out, log in as user B.
3. Export file as user B.
4. Compare files:
   - IDs in user A export must not appear in user B export.
   - Counts can differ, but user A data must never appear in B file.

## 3) Money format check

For each array item, confirm these fields are integers (cents):

- Installments: `cash_price_cents`, `installment_price_cents`, `down_payment_cents`, `monthly_payment_cents`
- Payments: `expected_amount_cents`, `paid_amount_cents`

No float values should exist in export JSON for money fields.

## 4) New-app import check

1. Open the new FinPay CRM app.
2. Go to **Settings -> Data migration**.
3. Import the exported file.
4. Confirm import succeeds without schema errors and counts match the old app.
