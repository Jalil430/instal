# Wallet System Design

## Overview

The wallet system replaces the current investor model with a comprehensive financial management system based on immutable ledger principles. It supports both personal wallets and Islamic investment partnership wallets, providing complete audit trails, real-time balance calculations, and profit-sharing functionality.

The design follows double-entry bookkeeping principles with an immutable transaction ledger and materialized balance cache for performance, ensuring financial integrity while supporting complex Islamic finance requirements.

## Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Wallet API    │    │  Transaction    │    │   Investment    │
│   Controller    │────│    Service      │────│    Service      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Wallet      │    │     Ledger      │    │  Installment    │
│   Repository    │    │   Repository    │    │   Repository    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   YDB Database  │
                    └─────────────────┘
```

### Data Flow

1. **Wallet Operations** → Transaction Service → Ledger Repository
2. **Balance Queries** → Wallet Repository → Materialized Balance Cache
3. **Investment Calculations** → Investment Service → Profit Distribution
4. **Installment Funding** → Transaction Service + Installment Repository

## Components and Interfaces

### 1. Wallet Entity

```dart
class Wallet {
  final String id;
  final String userId;
  final String name;
  final WalletType type; // personal, investor
  final String currency; // RUB
  final WalletStatus status; // active, archived
  final bool requireNonNegative;
  final bool allowPartialAllocation;
  
  // Investor-specific fields
  final double? investmentAmount;
  final double? investorPercentage;
  final double? userPercentage;
  final DateTime? investmentReturnDate;
  
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum WalletType { personal, investor }
enum WalletStatus { active, archived }
```

### 2. Ledger Transaction Entity

```dart
class LedgerTransaction {
  final String id;
  final String walletId;
  final String userId;
  final TransactionDirection direction; // credit, debit
  final int amountMinorUnits; // Rubles in kopecks (integer)
  final String currency;
  final TransactionType referenceType;
  final String? referenceId;
  final String? groupId; // Links related transactions
  final String? correlationId; // Idempotency key
  final String description;
  final String createdBy;
  final DateTime createdAt;
}

enum TransactionDirection { credit, debit }
enum TransactionType { 
  installment, 
  adjustment, 
  transfer, 
  reversal, 
  initial_investment,
  profit_distribution 
}
```

### 3. Wallet Balance (Materialized View)

```dart
class WalletBalance {
  final String walletId;
  final String userId;
  final int balanceMinorUnits;
  final int version; // Optimistic concurrency control
  final DateTime updatedAt;
}
```

### 4. Installment Allocation

```dart
class InstallmentAllocation {
  final String id;
  final String installmentId;
  final String walletId;
  final String userId;
  final int amountMinorUnits;
  final String transactionId;
  final AllocationStatus status; // active, void
  final DateTime createdAt;
}

enum AllocationStatus { active, void }
```

### 5. Investment Summary (Computed)

```dart
class InvestmentSummary {
  final String walletId;
  final int totalInvestedMinorUnits;
  final int currentBalanceMinorUnits;
  final int totalAllocatedMinorUnits;
  final int expectedReturnsMinorUnits;
  final int dueAmountMinorUnits;
  final DateTime? returnDueDate;
  final double profitPercentage;
}
```

## Data Models

### YDB Table Schemas

```sql
-- Wallets table
CREATE TABLE wallets (
    id Utf8,
    user_id Utf8,
    name Utf8,
    type Utf8, -- 'personal' | 'investor'
    currency Utf8, -- 'RUB'
    status Utf8, -- 'active' | 'archived'
    require_nonnegative Bool,
    allow_partial_allocation Bool,
    -- Investor-specific fields
    investment_amount_minor_units Int64?,
    investor_percentage Decimal(5,2)?,
    user_percentage Decimal(5,2)?,
    investment_return_date Date?,
    created_at Timestamp,
    updated_at Timestamp,
    PRIMARY KEY (user_id, id)
);

-- Wallet balances (materialized view)
CREATE TABLE wallet_balances (
    wallet_id Utf8,
    user_id Utf8,
    balance_minor_units Int64,
    version Uint64,
    updated_at Timestamp,
    PRIMARY KEY (user_id, wallet_id)
);

-- Ledger transactions (immutable)
CREATE TABLE ledger_transactions (
    id Utf8,
    wallet_id Utf8,
    user_id Utf8,
    direction Utf8, -- 'credit' | 'debit'
    amount_minor_units Int64,
    currency Utf8,
    reference_type Utf8, -- 'installment' | 'adjustment' | etc.
    reference_id Utf8?,
    group_id Utf8?,
    correlation_id Utf8?,
    description Utf8,
    created_by Utf8,
    created_at Timestamp,
    PRIMARY KEY (user_id, wallet_id, created_at, id)
);

-- Installment allocations
CREATE TABLE installment_allocations (
    id Utf8,
    installment_id Utf8,
    wallet_id Utf8,
    user_id Utf8,
    amount_minor_units Int64,
    transaction_id Utf8,
    status Utf8, -- 'active' | 'void'
    created_at Timestamp,
    PRIMARY KEY (user_id, installment_id, id)
);
```

### Money Handling

- **Storage**: All monetary values stored as integers in minor units (kopecks for rubles)
- **Conversion**: 1 RUB = 100 kopecks
- **Precision**: Eliminates floating-point precision issues
- **Display**: Convert to decimal for UI display (divide by 100)

## Error Handling

### Validation Rules

1. **Non-negative Balance**: Enforce when `require_nonnegative = true`
2. **Sufficient Funds**: Validate before creating debit transactions
3. **Wallet Status**: Only allow operations on active wallets
4. **Investment Constraints**: Validate investor percentage fields sum to 100%

### Concurrency Control

```dart
// Optimistic locking for balance updates
Future<void> updateBalance(String walletId, int amount) async {
  final balance = await getWalletBalance(walletId);
  final newBalance = balance.balanceMinorUnits + amount;
  
  if (newBalance < 0 && wallet.requireNonNegative) {
    throw InsufficientFundsException();
  }
  
  final updated = await updateWalletBalanceWithVersion(
    walletId, 
    newBalance, 
    balance.version
  );
  
  if (!updated) {
    throw ConcurrencyException('Balance was modified by another transaction');
  }
}
```

### Error Types

- `InsufficientFundsException`: Not enough balance for operation
- `WalletNotFoundException`: Wallet doesn't exist
- `ConcurrencyException`: Optimistic lock failure
- `InvalidOperationException`: Operation not allowed (e.g., on archived wallet)
- `ValidationException`: Input validation failures

## Testing Strategy

### Unit Tests

1. **Wallet Entity Tests**
   - Wallet creation with different types
   - Investment calculation methods
   - Validation rules

2. **Transaction Service Tests**
   - Credit/debit operations
   - Balance calculations
   - Concurrency scenarios

3. **Investment Service Tests**
   - Profit distribution calculations
   - Return date validations
   - Percentage-based calculations

### Integration Tests

1. **Database Operations**
   - Transaction atomicity
   - Balance consistency
   - Concurrent access patterns

2. **API Endpoints**
   - Wallet CRUD operations
   - Transaction history retrieval
   - Investment calculations

### End-to-End Tests

1. **Wallet Lifecycle**
   - Create → Fund → Allocate → Archive
   - Investment wallet with profit distribution

2. **Migration Scenarios**
   - Current investor data migration
   - Balance reconciliation
   - Historical data preservation

### Performance Tests

1. **Balance Calculation Performance**
   - Large transaction volumes
   - Concurrent balance queries
   - Materialized view efficiency

2. **Transaction Throughput**
   - High-frequency operations
   - Batch processing scenarios
   - Database connection pooling

## Investment Calculation Logic

### Wallet Growth Model

The investment calculation is based on wallet growth through installment business operations:

```dart
class InvestmentCalculator {
  static InvestmentSummary calculateReturns(
    Wallet investorWallet,
    WalletBalance currentBalance,
    List<InstallmentAllocation> allocations
  ) {
    // Calculate total wallet value (balance + allocated funds)
    final totalAllocated = allocations
        .where((a) => a.status == AllocationStatus.active)
        .fold(0, (sum, a) => sum + a.amountMinorUnits);
    
    final totalWalletValue = currentBalance.balanceMinorUnits + totalAllocated;
    
    // Calculate profit generated by wallet growth
    final totalProfit = totalWalletValue - investorWallet.investmentAmountMinorUnits!;
    
    // Calculate investor's share of the profit
    final investorProfitShare = totalProfit > 0 
        ? (totalProfit * investorWallet.investorPercentage! / 100).round()
        : 0;
    
    // Expected returns = Initial Investment + Investor's Profit Share
    final expectedReturns = investorWallet.investmentAmountMinorUnits! + investorProfitShare;
    
    return InvestmentSummary(
      walletId: investorWallet.id,
      totalInvestedMinorUnits: investorWallet.investmentAmountMinorUnits!,
      currentBalanceMinorUnits: currentBalance.balanceMinorUnits,
      totalAllocatedMinorUnits: totalAllocated,
      expectedReturnsMinorUnits: expectedReturns,
      dueAmountMinorUnits: calculateDueAmount(investorWallet, expectedReturns),
      returnDueDate: investorWallet.investmentReturnDate,
      profitPercentage: investorWallet.investorPercentage!,
    );
  }
}
```

### Business Model Flow

1. **Initial Investment**: Investor provides capital (e.g., 1,000,000 RUB)
2. **Product Purchase**: User buys products using wallet funds (e.g., iPhone for 80,000 RUB)
3. **Installment Sale**: User sells product on installment for higher price (e.g., 100,000 RUB)
4. **Payment Collection**: Installment payments flow back to the same wallet
5. **Wallet Growth**: Wallet value increases through successful business operations
6. **Profit Calculation**: Total Profit = Current Wallet Value - Initial Investment
7. **Profit Distribution**: Investor gets their percentage of the total profit generated

### Islamic Finance Compliance

- **No Interest Calculations**: Use profit-sharing percentages only
- **Partnership Model**: Clear investor/user percentage splits
- **Profit-based Returns**: Returns based on actual business performance
- **Transparent Agreements**: All terms clearly displayed and recorded