# Wallet System Implementation Plan

- [x] 1. Create core wallet domain entities and models
  - Implement Wallet entity with personal and investor types
  - Create LedgerTransaction entity with immutable transaction records
  - Implement WalletBalance entity for materialized balance caching
  - Create InstallmentAllocation entity for tracking funding sources
  - Add money handling utilities for minor units (kopecks) conversion
  - Write unit tests for all domain entities and validation rules
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2_

- [x] 2. Implement wallet repository layer with YDB integration
  - Create wallet repository interface and implementation
  - Implement ledger transaction repository with time-ordered queries
  - Create wallet balance repository with optimistic concurrency control
  - Implement installment allocation repository
  - Add database connection utilities and error handling
  - Write integration tests for all repository operations
  - _Requirements: 2.1, 2.2, 2.3, 5.4, 5.5_

- [x] 3. Build transaction service for ledger operations
  - Implement credit/debit transaction creation with validation
  - Create balance calculation service using ledger aggregation
  - Implement transaction grouping for multi-wallet operations
  - Add concurrency control with optimistic locking
  - Create transaction reversal functionality
  - Write unit tests for transaction service operations
  - _Requirements: 2.1, 2.2, 2.3, 5.1, 5.2, 5.5_

- [x] 4. Develop wallet management service
  - Implement wallet creation for personal and investor types
  - Create wallet balance management with non-negative constraints
  - Implement wallet archival functionality
  - Add wallet validation rules and business logic
  - Create wallet search and filtering capabilities
  - Write unit tests for wallet management operations
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 5.4_

- [x] 5. Implement investment calculation service
  - Create investment summary calculation logic
  - Implement profit distribution calculations based on percentages
  - Add return date tracking and due amount calculations
  - Create Islamic finance compliance validation
  - Implement investment performance analytics
  - Write unit tests for investment calculations
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 8.1, 8.3_

- [x] 6. Build installment allocation service
  - Implement installment funding from specific wallets
  - Create allocation validation with balance checking
  - Implement allocation voiding with transaction reversals
  - Add multi-wallet allocation support (future enhancement)
  - Create allocation history tracking
  - Write unit tests for allocation operations
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 7. Create wallet API endpoints
  - Implement POST /wallets for wallet creation
  - Create GET /wallets for wallet listing with balances
  - Implement POST /wallets/{id}/top-up for adding funds
  - Create POST /wallets/{id}/adjust for manual adjustments
  - Implement POST /wallets/transfer for inter-wallet transfers
  - Add GET /wallets/{id}/ledger for transaction history
  - Write API integration tests for all endpoints
  - _Requirements: 1.1, 1.4, 5.1, 5.2, 5.3, 6.1_

- [x] 8. Implement installment allocation API endpoints
  - Create POST /installments/{id}/allocate for funding installments
  - Implement POST /installments/{id}/allocations/{allocId}/void for reversals
  - Add GET /installments/{id}/allocations for allocation history
  - Create validation for sufficient wallet balance
  - Implement allocation status tracking
  - Write API integration tests for allocation endpoints
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 9. Build wallet management UI screens
  - Create wallets list screen with balance display and quick actions
  - Implement wallet creation form with type selection
  - Create wallet detail screen with transaction history
  - Implement top-up and adjustment forms
  - Add wallet transfer functionality
  - Create wallet archival interface
  - Write widget tests for wallet UI components
  - _Requirements: 1.1, 1.4, 5.1, 5.2, 5.3, 6.1_

- [ ] 10. Implement investor wallet UI features
  - Create investor wallet creation form with investment terms
  - Implement investment summary display with profit calculations
  - Add return date tracking and due amount visualization
  - Create profit distribution interface
  - Implement investment performance analytics view
  - Write widget tests for investor-specific UI components
  - _Requirements: 1.3, 1.5, 4.1, 4.2, 4.3, 4.4, 8.2_

- [ ] 11. Update installment creation UI for wallet selection
  - Modify installment creation form to include wallet selection
  - Add wallet balance display and validation
  - Implement funding source tracking in installment details
  - Create allocation history view in installment screens
  - Add wallet-based filtering for installment lists
  - Write widget tests for updated installment UI
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 12. Implement wallet transaction history and reporting
  - Create wallet transaction history with filtering and pagination
  - Implement wallet growth tracking (initial investment → final amount)
  - Add CSV export functionality for transaction data
  - Create wallet performance dashboard showing growth metrics
  - Implement investment return calculations based on profit distribution percentages
  - Track money flow: installment payments → wallet → profit distribution
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 13. Build data migration service
  - Create migration script to convert existing investors to wallets
  - Implement "My Wallet" creation for all users
  - Create investor wallet migration with investment terms
  - Implement installment allocation migration
  - Add data validation and rollback capabilities
  - Write integration tests for migration process
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 14. Implement wallet state management and providers
  - Create wallet provider for state management
  - Implement transaction provider for ledger operations
  - Add investment calculation provider
  - Create allocation provider for installment funding
  - Implement real-time balance updates
  - Write unit tests for all providers
  - _Requirements: 1.4, 2.4, 5.5_

- [ ] 15. Add comprehensive error handling and validation
  - Implement wallet operation error handling
  - Create user-friendly error messages for insufficient funds
  - Add validation for investment percentage constraints
  - Implement concurrency error handling with retry logic
  - Create error logging and monitoring
  - Write unit tests for error scenarios
  - _Requirements: 5.5, 8.4_

- [ ] 16. Integrate wallet system with existing features
  - Update navigation to include wallets screen
  - Modify analytics dashboard to include wallet metrics
  - Update user settings to include wallet preferences
  - Integrate wallet notifications for low balances
  - Update localization files with wallet-related strings
  - Write end-to-end tests for integrated functionality
  - _Requirements: 1.4, 6.5_

- [ ] 17. Implement performance optimizations
  - Add database indexing for transaction queries
  - Implement balance caching strategies
  - Create batch processing for large transaction volumes
  - Add pagination for transaction history
  - Implement lazy loading for wallet lists
  - Write performance tests and benchmarks
  - _Requirements: 2.4, 6.1_

- [ ] 18. Add Islamic finance compliance features
  - Implement profit-sharing calculation validation
  - Create partnership agreement display
  - Add Sharia-compliant reporting features
  - Implement flexible profit distribution based on performance
  - Create compliance audit trail
  - Write unit tests for compliance features
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_