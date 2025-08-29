# Wallet System Overhaul — Requirements

## Goals
- Use installment payments as the single source of truth for all wallet calculations (investor and personal wallets).
- Persist fast, consistent wallet aggregates in `wallet_balances` to avoid expensive runtime scans:
  - `total_allocated_minor_units`
  - `due_to_get_minor_units`
  - `expected_revenue_minor_units`
- Support partial payments on installments and recalculate the remaining schedule accordingly by updating `paid_amount` and mutating `expected_amount` on upcoming payments.
- Ensure all wallet aggregates are updated atomically whenever allocations or payments change.
- Replace mock wallets in the Create Installment flow with real data and balances.

## Non‑Goals
- Multi‑currency handling (assume RUB minor units everywhere).
- Historical PnL reporting beyond the aggregates above.
- Multi‑wallet funding per installment (future compatible, but not required for this iteration).

## Terminology
- Minor units: kopecks (RUB cents), `Int64` in YDB for wallet amounts.
- Expected amount: per‑payment planned amount (Decimal in `installment_payments`).
- Actual paid amount: what user actually paid for that payment (Decimal).

## Current Pain Points
1. Expected revenue formula is inconsistent and not tied to installment payments.
2. Personal/investor UI uses mixed conditions; results are confusing.
3. Create Installment dialog shows mock wallets instead of real ones.
4. Aggregates require scanning allocations/payments at read‑time → slow and error‑prone.
5. Partial payments aren’t supported; we need to let user enter custom paid amount and reflow remaining schedule.

## Functional Requirements
1. A user can create installments linked to a wallet (directly via `installments.wallet_id` or via allocation event).
2. A user can record a payment with a custom amount (partial or full):
   - Store `actual_paid_amount` for the payment.
   - If partial (< expected), keep `is_paid = false` and reduce remaining schedule accordingly.
   - If overpay (> expected), mark this payment paid and redistribute excess across next unpaid payments.
3. Wallet aggregates must be updated after any of:
   - Allocation create/void
   - Payment create/update/delete
   - Installment create/archive (if applicable)
4. Fast reads: `/wallets` and `/wallets/{id}` return the aggregates from `wallet_balances`.
5. Create Installment dialog lists real wallets + real balances and respects non‑negative constraints.

## Aggregate Definitions
- `total_allocated_minor_units`:
  - Sum of `installment_allocations.amount_minor_units` with `status='active'` for the wallet.
- `due_to_get_minor_units`:
  - Sum of remaining expected amounts on unpaid payments for installments linked to the wallet.
  - Remaining expected amounts reflect partial payments and schedule recalculation.
- `expected_revenue_minor_units` (investor wallets):
  - Let `projected_balance = balance_minor_units + due_to_get_minor_units`.
  - Profit base = `projected_balance - investment_amount_minor_units` (>= 0).
  - Investor share = `profit_base * investor_percentage / 100`.
  - For personal wallets, `expected_revenue_minor_units = 0`.

## Data Consistency Requirements
- Use optimistic locking on `wallet_balances.version` for balance and aggregate updates (already present for balance; extend to aggregates as one atomic record update).
- Updates must be transactional with the driving event (allocation or payment) to avoid drift.
- Provide an on‑demand recompute function to rebuild aggregates from source tables.

## UI/UX Requirements
- Wallet list shows correct balances and relies on stored aggregates where useful.
- Wallet details use aggregates from `wallet_balances`:
  - Given to installment = `total_allocated_minor_units`
  - Due to get = `due_to_get_minor_units`
  - Expected revenue = `expected_revenue_minor_units` (investor only)
- Create Installment dialog:
  - Show real wallets + balances
  - If wallet selected and `require_nonnegative`, prevent allocation that would make balance negative

## Performance & Scale
- Reads should not scan payments live; rely on persisted aggregates.
- Writes update few rows (payments, one wallet balance, maybe one allocation), O(1) per event.

## Security
- All endpoints behind JWT; user_id is enforced on every query.

---
