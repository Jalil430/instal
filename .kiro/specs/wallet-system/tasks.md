# Wallet System Overhaul — Tasks

## Phase 0 — Prep & Migrations
- [ ] Add columns to `wallet_balances`:
  - [ ] `total_allocated_minor_units Int64`
  - [ ] `due_to_get_minor_units Int64`
  - [ ] `expected_revenue_minor_units Int64`
- [ ] Add `paid_amount Decimal(22,9)` to `installment_payments`
- [ ] Ship read APIs that default missing aggregates to 0 to avoid breakage

## Phase 1 — Client Wiring (Create Installment)
- [x] Replace mock wallets with real repository in `CreateInstallmentDialog`
- [ ] Enforce `require_nonnegative` when selecting/confirming wallet

## Phase 2 — API/Backend Write Paths
- Allocation (`functions/allocate-installment/index.py`)
  - [ ] After successful allocation, update wallet_balances fields atomically:
    - [ ] `balance_minor_units` (existing)
    - [ ] `total_allocated_minor_units += amount`
    - [ ] `due_to_get_minor_units += SUM(expected_amount of unpaid payments for that installment)`
    - [ ] `expected_revenue_minor_units = recalc()`
  - [ ] If installment.wallet_id is null, set it to wallet_id

- Void allocation (`functions/void-installment-allocation/index.py`)
  - [ ] Reverse allocation effects on aggregates and `balance_minor_units`

- Payment update (`functions/update-installment-payment/index.py`)
  - [ ] Accept `paid_amount` in body
  - [ ] Update `installment_payments.paid_amount += paid_amount`
  - [ ] If reaches/exceeds expected_amount ⇒ mark paid, cascade overpay to next unpaid payments
  - [ ] Else partial ⇒ recalc remaining unpaid payments so their sum equals outstanding amount
  - [ ] Update `installments.paid_amount`, `remaining_amount`, `next_payment_*`, etc (adjust logic to use `paid_amount` and mutated `expected_amount`)
  - [ ] If installment.wallet_id present:
    - [ ] Credit wallet ledger & `balance_minor_units += paid_amount_minor_units`
    - [ ] Decrease `due_to_get_minor_units -= paid_amount_minor_units`
    - [ ] Recalc `expected_revenue_minor_units`

- Recompute job (`functions/recompute-wallet-aggregates/index.py`)
  - [ ] CLI/HTTP function to rebuild all wallets’ aggregates from source tables

## Phase 3 — Read APIs
- get-wallet/list-wallets
  - [ ] Include the three aggregate fields in `balance` block directly from `wallet_balances`
  - [ ] Remove on‑the‑fly sums where feasible (keep a fallback only until backfill)

## Phase 4 — Client Adoption
- Wallet Details/List screens
  - [ ] Consume `total_allocated_minor_units`, `due_to_get_minor_units`, `expected_revenue_minor_units` from API
  - [ ] Remove ad‑hoc derivations

## Phase 5 — Data Backfill
- [ ] Run recompute for all wallets
- [ ] Verify aggregates match expectations on sample datasets

## Phase 6 — QA & Polishing
- [ ] Partial payment edge cases (zero expected next, roundings)
- [ ] Concurrency under load (simulating two updates)
- [ ] Error handling and retry of wallet aggregate updates

## Optional Enhancements
- [ ] Support multi‑wallet funding per installment with proportionate payment apportioning
- [ ] Add audit table for payment adjustments (before/after expected_amount) for history
