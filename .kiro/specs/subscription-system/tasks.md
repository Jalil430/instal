# Implementation Plan

- [x] 1. Create subscription domain layer foundation
  - Create subscription entities with proper enums and data structures
  - Define repository interface for subscription operations
  - Implement use cases for code validation and status checking
  - _Requirements: 3.1, 3.2, 4.1, 5.1, 6.1, 7.1_

- [x] 2. Implement subscription data layer
  - Create subscription model with JSON serialization
  - Implement remote data source for API communication
  - Implement local data source for caching subscription state
  - Create repository implementation that coordinates remote and local data
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 3. Create backend serverless functions
  - Implement validate-subscription-code function with server-side date calculation
  - Implement check-subscription-status function with server-side expiration checking
  - Ensure all date/time operations use server timestamps to prevent client manipulation
  - Add proper error handling and response formatting for both functions
  - Test duration calculation logic using server time for different subscription types
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.2, 7.3, 7.4_

- [x] 4. Build subscription presentation layer
  - Create subscription provider for state management
  - Implement subscription screen with responsive design
  - Create subscription status message widget with different text for user states
  - Add form validation and error handling for code input
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 3.5, 3.6_

- [x] 5. Implement subscription guard widget
  - Create SubscriptionGuard widget that wraps main app content
  - Add subscription status checking logic on app startup
  - Implement navigation logic to show subscription screen or main app
  - Handle multiple subscription scenarios and active status determination
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4_

- [x] 6. Integrate subscription system with existing app architecture
  - Modify app router to include SubscriptionGuard in protected routes
  - Update main.dart to initialize subscription services
  - Add subscription-related localization strings
  - Ensure proper integration with existing AuthGuard flow
  - _Requirements: 1.1, 2.1, 4.1_

- [ ] 7. Add comprehensive error handling and user feedback
  - Implement error handling for invalid, used, and expired codes
  - Add loading states and user feedback during code validation
  - Create user-friendly error messages with localization support
  - Add retry logic for network failures
  - _Requirements: 3.5, 6.2_

- [ ] 8. Create unit tests for subscription domain logic
  - Write tests for subscription entities and enums
  - Test use cases for code validation and status checking
  - Test subscription state determination logic with server-side time scenarios
  - Test duration calculation for different subscription types using mock server timestamps
  - Test expiration logic to ensure client time cannot affect subscription validity
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 7.2, 7.3, 7.4, 7.5_

- [ ] 9. Create integration tests for subscription data layer
  - Test repository implementation with mock data sources
  - Test API integration with backend functions
  - Test local caching functionality
  - Test error handling and network failure scenarios
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 10. Create widget tests for subscription UI components
  - Test SubscriptionScreen with different user status scenarios
  - Test SubscriptionGuard navigation logic
  - Test form validation and error display
  - Test responsive design on different screen sizes
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 3.3, 3.4, 3.5, 3.6_