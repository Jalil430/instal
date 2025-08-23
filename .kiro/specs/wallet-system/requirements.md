# Wallet System Requirements

## Introduction

Transform the current investor system into a comprehensive wallet-based system that supports both personal wallets and investor partnership wallets. The system will use an immutable ledger approach for financial integrity while maintaining Islamic finance compliance through investment tracking and profit-sharing calculations.

**Business Model**: Investor wallets provide capital for installment business operations. Users purchase products using wallet funds and sell them on installment plans. All installment payments flow back to the same wallet, causing it to grow over time. Profit is calculated as the difference between current wallet value and initial investment, then distributed according to agreed percentages.

## Requirements

### Requirement 1: Wallet Management

**User Story:** As a user, I want to create and manage different types of wallets, so that I can organize my funding sources and track financial flows for my installment business operations.

#### Acceptance Criteria

1. WHEN creating a wallet THEN the system SHALL support wallet types: "personal" and "investor"
2. WHEN creating a personal wallet THEN the system SHALL allow setting an initial balance
3. WHEN creating an investor wallet THEN the system SHALL require investment amount, investor percentage, user percentage, and investment return date
4. WHEN displaying wallets THEN the system SHALL show current balance, allocated funds, total wallet value, and key details
5. IF wallet type is "investor" THEN the system SHALL display investment terms, profit calculations, and expected returns based on wallet growth

### Requirement 2: Immutable Transaction Ledger

**User Story:** As a business owner, I want all financial transactions to be permanently recorded, so that I have complete audit trails and can ensure data integrity.

#### Acceptance Criteria

1. WHEN any wallet operation occurs THEN the system SHALL create immutable ledger transactions
2. WHEN recording transactions THEN the system SHALL use credit/debit entries with reference information
3. WHEN multiple wallets are involved THEN the system SHALL group related transactions
4. WHEN displaying transaction history THEN the system SHALL show chronological, filterable ledger entries
5. WHEN calculating balances THEN the system SHALL derive from sum of credits minus debits

### Requirement 3: Installment Funding

**User Story:** As a user, I want to fund installments from specific wallets, so that I can track which funding source is used for each deal.

#### Acceptance Criteria

1. WHEN creating an installment THEN the system SHALL allow selecting a funding wallet
2. WHEN funding an installment THEN the system SHALL validate sufficient wallet balance
3. WHEN allocation is confirmed THEN the system SHALL create debit transaction and reduce wallet balance
4. WHEN viewing installments THEN the system SHALL show funding wallet and allocation details
5. IF allocation needs to be voided THEN the system SHALL create reversal transaction and restore balance

### Requirement 4: Investment Partnership Calculations

**User Story:** As an investor partner, I want the system to calculate my expected returns based on wallet growth and profit-sharing agreements, so that I can track my investment performance in the installment business.

#### Acceptance Criteria

1. WHEN creating investor wallet THEN the system SHALL store initial investment amount, profit-sharing percentages, and return date
2. WHEN wallet grows through installment business THEN the system SHALL calculate total profit as (Current Wallet Value - Initial Investment)
3. WHEN viewing investor wallet THEN the system SHALL display initial investment, current wallet value, total profit generated, and investor's profit share
4. WHEN calculating profit distribution THEN the system SHALL apply investor percentage to total wallet profit only
5. WHEN investment return date approaches THEN the system SHALL calculate total amount due as (Initial Investment + Investor's Profit Share)

### Requirement 5: Wallet Operations

**User Story:** As a user, I want to perform various wallet operations like deposits, withdrawals, and transfers, so that I can manage my financial resources effectively.

#### Acceptance Criteria

1. WHEN adding funds THEN the system SHALL create credit transaction and increase balance
2. WHEN withdrawing funds THEN the system SHALL create debit transaction and decrease balance
3. WHEN transferring between wallets THEN the system SHALL create linked debit/credit transactions
4. WHEN performing operations THEN the system SHALL enforce non-negative balance constraints
5. WHEN operations fail THEN the system SHALL maintain data consistency and provide clear error messages

### Requirement 6: Financial Reporting and Analytics

**User Story:** As a business owner, I want to view financial reports and analytics, so that I can understand cash flows, investment performance, and business profitability.

#### Acceptance Criteria

1. WHEN viewing wallet details THEN the system SHALL show transaction history with filtering options
2. WHEN analyzing investments THEN the system SHALL display profit calculations and return projections
3. WHEN generating reports THEN the system SHALL support export to CSV format
4. WHEN tracking performance THEN the system SHALL show expense, income, and remainder calculations similar to current Excel tracking
5. WHEN viewing dashboard THEN the system SHALL display key metrics: total wallet balances, active investments, pending returns

### Requirement 7: Migration from Current System

**User Story:** As an existing user, I want my current investor data to be migrated to the new wallet system, so that I don't lose historical information.

#### Acceptance Criteria

1. WHEN migration runs THEN the system SHALL create "My Wallet" for each user
2. WHEN migrating investors THEN the system SHALL create investor wallets with existing investment amounts
3. WHEN migrating installments THEN the system SHALL create allocation records linking installments to investor wallets
4. WHEN migration completes THEN the system SHALL preserve all existing financial relationships
5. WHEN using migrated data THEN the system SHALL maintain backward compatibility for reporting

### Requirement 8: Islamic Finance Compliance

**User Story:** As a user following Islamic finance principles, I want the system to support profit-sharing partnerships and avoid interest-based calculations, so that my business remains Sharia-compliant.

#### Acceptance Criteria

1. WHEN calculating returns THEN the system SHALL use profit-sharing percentages, not interest rates
2. WHEN displaying investment terms THEN the system SHALL show partnership agreements clearly
3. WHEN tracking profits THEN the system SHALL separate business profits from principal amounts
4. WHEN generating reports THEN the system SHALL distinguish between investment returns and operational income
5. WHEN managing partnerships THEN the system SHALL support flexible profit distribution based on actual business performance