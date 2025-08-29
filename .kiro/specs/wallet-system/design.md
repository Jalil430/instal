# Wallet System Overhaul — Design

## 1. Schema Changes (YDB)

### 1.1 `wallet_balances`
Add aggregate fields (all Int64 minor units):
```
ALTER TABLE wallet_balances ADD COLUMN total_allocated_minor_units Int64;
ALTER TABLE wallet_balances ADD COLUMN due_to_get_minor_units Int64;
ALTER TABLE wallet_balances ADD COLUMN expected_revenue_minor_units Int64;
```
Populate defaults to 0 for existing rows.

### 1.2 `installment_payments`
Support partial payments and schedule reflow:
```
ALTER TABLE installment_payments ADD COLUMN paid_amount Decimal(22,9);
-- Optional future fields for audit:
```
Notes:
- `expected_amount` is mutable and represents the remaining amount for that payment after adjustments.
- `paid_amount` accumulates the paid total for this payment; if it reaches expected_amount → mark `is_paid = true` and set `paid_date`.
- If a payment is over/under the expected, redistribute the delta to the rest of unpaid payments (see 2.3) by directly modifying their `expected_amount` values.

### 1.3 `installments`
We will use the existing `wallet_id` column as the primary link to a wallet. `installment_allocations` remains as the journal of funding events.

## 2. Calculations & Flows

### 2.1 Aggregates Stored in `wallet_balances`
- `total_allocated_minor_units` = sum of active allocations (minor units)
- `due_to_get_minor_units` = sum of `expected_amount` for unpaid payments for installments with `wallet_id = this.wallet_id`
- `expected_revenue_minor_units` (investor wallets) =
  - `projected_balance = balance_minor_units + due_to_get_minor_units`
  - `profit_base = max(0, projected_balance - investment_amount_minor_units)`
  - `expected_revenue = profit_base * investor_percentage / 100`
  - For personal wallets = 0

### 2.2 Allocation Flow
Event: allocate funds from wallet to installment (existing `allocate-installment`)
- Create allocation record (debit wallet ledger, decrease `balance_minor_units`)
- Update `total_allocated_minor_units += amount`
- If installment has a wallet_id unset, set it to this wallet_id
- Recompute `due_to_get_minor_units` for this wallet: add sum of unpaid `expected_amount` for this installment
- Recompute `expected_revenue_minor_units`

Void allocation:
- Reverse the above (credit wallet, decrease `total_allocated_minor_units`, remove installment from due_to_get if no longer linked)

### 2.3 Payment Flow (Partial Supported)
Event: update installment payment (existing `update-installment-payment`)
- Input: `is_paid` and optional `paid_date`, PLUS a new `paid_amount` (double/Decimal) indicating how much user actually paid now.
- Update logic (inside a serializable transaction):
  1) Increment `actual_paid_amount` for this payment by `paid_amount`.
  2) If `actual_paid_amount >= expected_amount`:
     - Set `is_paid = true`, `paid_date` accordingly
     - Excess overpayment (if any) = `actual_paid_amount - expected_amount` → cascade to next unpaid payment(s) as automatic adjustment:
       - Reduce next unpaid payment's `expected_amount` by the excess; if it goes <= 0, mark paid and continue cascading.
  3) Else (partial): Keep `is_paid = false`; reduce all remaining unpaid payments proportionally so their sum equals outstanding `installment_price - sum(actual_paid_amount paid)`.
  4) Update `installments.paid_amount`, `remaining_amount`, next/last payment info (already present in handler; extend to use `actual_paid_amount`).

Wallet updates from payment:
- If installment has `wallet_id` set:
  - Increase `wallet_balances.balance_minor_units` by `paid_amount_minor_units` (credit ledger txn)
  - Decrease `due_to_get_minor_units` by `paid_amount_minor_units` (since part of expected inflow is now received)
  - Recompute `expected_revenue_minor_units`

Delete payment (if supported):
- Reverse the above deltas; recalc schedule (increase expected_amounts); recalculates `due_to_get`, etc.

## 3. APIs & Cloud Functions Changes

### 3.1 New/Changed Fields
- `GET /wallets` and `GET /wallets/{id}`
  - Return `balance` object extended with `total_allocated_minor_units`, `due_to_get_minor_units`, `expected_revenue_minor_units`.
- `POST /installments` (create)
  - Accept optional `wallet_id` to link the installment to a wallet immediately.
  - Optionally trigger an automatic allocation (future enhancement flag).
- `POST /installments/{installment_id}/allocate` and `POST /void` (existing)
  - Update wallet aggregates transactionally with allocation change.
- `PUT /installment-payments/{id}` (existing update)
  - Accept `paid_amount` Decimal
  - Update `actual_paid_amount` and recalc schedule; then update wallet aggregates as described.
- `POST /wallets/recompute-aggregates` (new)
  - Recompute all wallets’ aggregates from scratch (for migration/repair).

### 3.2 Function Touchpoints
- allocate-installment/index.py
  - After allocation succeeds, update wallet_balances:
    - `balance_minor_units` (already), `total_allocated_minor_units`, `due_to_get_minor_units` (add sum expected of installment), `expected_revenue_minor_units` (recalc)
- void-installment-allocation/index.py
  - Reverse allocation deltas; recompute aggregates
- update-installment-payment/index.py
  - Accept `paid_amount` and apply partial/overpayment logic; update wallet balances and aggregates
- get-wallet/index.py and list-wallets/index.py
  - Join/compose from stored aggregates (instead of on-the-fly sums)
- create-installment/index.py
  - Allow optional `wallet_id`
  - Do not update aggregates here unless an allocation happens; `due_to_get` is driven by payments and allocations
- recompute-wallet-aggregates/index.py (new utility)
  - For a wallet (or all wallets): recompute `total_allocated`, `due_to_get`, `expected_revenue` from source tables

## 4. Client Changes

### 4.1 Create Installment Dialog
- Uses `WalletRepository` to load real wallets/balances (implemented in code).
- Enforce `require_nonnegative` at selection/submit time.

### 4.2 Wallet Details & List
- Replace ad‑hoc derived values with new fields from `balance` object when present:
  - `total_allocated_minor_units`
  - `due_to_get_minor_units`
  - `expected_revenue_minor_units`

## 5. Migrations & Backfill
1) Apply YDB ALTER TABLEs.
2) Write a one‑off Cloud Function/script to:
   - Initialize new wallet aggregate columns to 0
   - For each wallet:
     - `total_allocated` = SUM allocations active
     - `due_to_get` = SUM expected_amount of unpaid payments of installments where `wallet_id = wallet.id`
     - `expected_revenue` = as per formula
   - Update `wallet_balances` with optimistic lock

## 6. Transactions & Concurrency
- Use SerializableReadWrite transactions when updating both payment state and wallet aggregates.
- Keep a local copy of `wallet_balances.version` to enforce optimistic concurrency (`WHERE version = expected_version`).

## 7. Testing Strategy
- Unit tests for payment update scenarios (partial, full, overpay cascade).
- Integration tests for:
  - Allocation → aggregates updated
  - Payment update → aggregates updated; wallet balance & due_to_get move oppositely
  - Recompute job produces same results as incremental updates

## 8. Rollout Plan
1) Ship schema changes with aggregates defaulted to 0.
2) Deploy updated read APIs to tolerate missing aggregate fields (fallback to 0).
3) Deploy write paths (allocation & payment updates) that start updating the new fields.
4) Run recompute job to backfill.
5) Switch clients to read the new aggregate fields for details/list.
