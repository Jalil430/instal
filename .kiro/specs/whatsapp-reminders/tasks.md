# Implementation Plan

- [x] 1. Set up backend infrastructure and shared utilities
  - Create shared WhatsApp service module for Green API integration
  - Implement message template processing with variable substitution
  - Create database schema for WhatsApp settings storage
  - _Requirements: 5.1, 5.2, 4.2, 4.3_

- [x] 2. Implement automatic reminder backend function
  - [x] 2.1 Create send-auto-reminders function structure
    - Set up function directory and basic handler structure
    - Implement authentication using existing JWT auth pattern
    - Create database connection and session management
    - _Requirements: 6.1, 6.3_

  - [x] 2.2 Implement batch message sending logic for automatic reminders
    - Query installments due in 7 days and today using existing installment utilities
    - Process multiple installments in single function execution
    - Implement Green API integration for message sending using existing WhatsApp service
    - Add error handling for individual message failures
    - Create response formatting with success/failure details
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 6.5, 8.1, 8.2_

- [x] 3. Implement manual reminder backend function
  - [x] 3.1 Create send-manual-reminder function structure
    - Set up function directory and request handling
    - Implement authentication and input validation
    - Create installment ID processing for single and bulk operations
    - _Requirements: 6.2, 6.4, 7.2_

  - [x] 3.2 Implement single and bulk reminder sending
    - Query specific installments by ID with client details using existing utilities
    - Generate personalized messages using manual template
    - Send messages via Green API with individual error handling
    - Return detailed results for each processed installment
    - _Requirements: 3.2, 7.3, 7.4, 7.5_

- [x] 4. Create WhatsApp settings backend endpoints
  - [x] 4.1 Create get-whatsapp-settings function
    - Implement GET endpoint for retrieving WhatsApp settings using existing repository
    - Add authentication and user validation
    - Return settings with masked credentials for security
    - _Requirements: 5.3, 5.4_

  - [x] 4.2 Create update-whatsapp-settings function
    - Implement PUT endpoint for updating settings and credentials
    - Add Green API connection testing endpoint
    - Validate template format and variables
    - _Requirements: 5.3, 5.4, 5.5_

  - [x] 4.3 Create test-whatsapp-connection function
    - Implement standalone endpoint for testing Green API credentials
    - Return connection status and error details
    - _Requirements: 5.4, 5.5_

  - [x] 4.4 Update API Gateway configuration
    - Add new WhatsApp endpoints to instal-api.yaml
    - Configure function IDs for new reminder and settings functions
    - Update CORS settings for new endpoints
    - _Requirements: 6.1, 6.2_

- [x] 5. Implement frontend WhatsApp settings screen
  - [x] 5.1 Create WhatsApp settings UI components
    - Design settings screen layout with credential fields
    - Implement Green API instance ID and token input fields
    - Create connection test button with loading states
    - Add success/error feedback for connection testing
    - _Requirements: 5.1, 5.3, 5.4_

  - [x] 5.2 Implement template editor interface
    - Create template editor with syntax highlighting for variables
    - Implement variable helper display showing available placeholders
    - Add template validation with real-time error feedback
    - Create separate editors for 7-day, due-today, and manual templates
    - _Requirements: 4.1, 4.2, 4.4, 4.5_

  - [x] 5.3 Integrate settings with backend API
    - Implement API calls for loading and saving WhatsApp settings
    - Add error handling for API failures and validation errors
    - Create settings persistence with local caching
    - _Requirements: 4.3, 5.2_

- [x] 6. Enhance installments list with manual reminder functionality
  - [x] 6.1 Add context menu option for WhatsApp reminders
    - Modify installment list item to include right-click context menu
    - Add "Send WhatsApp Reminder" option to existing context menu
    - Implement context menu action handling for reminder sending
    - _Requirements: 3.1, 3.2_

  - [x] 6.2 Implement manual reminder API integration
    - Create API service method for sending manual reminders
    - Implement single installment reminder sending from context menu
    - Add success/error notification display for manual reminders
    - Handle API errors with user-friendly error messages
    - _Requirements: 3.3, 3.4, 3.5_

- [ ] 7. Implement bulk reminder functionality
  - [x] 7.1 Add multi-select capability to installments list
    - Implement checkbox selection for installment list items
    - Create select all/none functionality for bulk operations
    - Add visual indicators for selected items
    - _Requirements: 7.1_

  - [x] 7.2 Create bulk reminder action interface
    - Implement bulk action toolbar with reminder sending option
    - Add progress indicator for bulk reminder operations
    - Create bulk reminder confirmation dialog
    - _Requirements: 7.2, 7.3_

  - [x] 7.3 Implement bulk reminder processing
    - Send multiple installment IDs to manual reminder function
    - Display progress feedback during bulk processing
    - Show detailed results summary with success/failure counts
    - Handle partial failures with retry options
    - _Requirements: 7.4, 7.5_

- [x] 8. Create WhatsApp service integration layer
  - [x] 8.1 Implement Green API client wrapper
    - Create HTTP client for Green API communication
    - Implement authentication header management
    - Add request/response logging for debugging
    - _Requirements: 5.2, 8.1_

  - [x] 8.2 Implement message formatting and sending
    - Create message template processing with variable substitution
    - Implement phone number validation and formatting
    - Add message sending with retry logic and error handling
    - Create rate limiting compliance mechanisms
    - _Requirements: 1.3, 2.3, 3.3, 8.2, 8.3, 8.4_

- [x] 9. Add comprehensive error handling and logging
  - [x] 9.1 Implement backend error handling
    - Add structured logging for all WhatsApp operations
    - Implement retry mechanisms for transient failures
    - Create error categorization (retryable vs permanent)
    - Add graceful degradation for API unavailability
    - _Requirements: 8.1, 8.2, 8.5_

  - [x] 9.2 Implement frontend error handling
    - Add error boundary components for WhatsApp features
    - Implement offline capability detection and messaging
    - Create user-friendly error messages for common failures
    - Add error recovery options and retry mechanisms
    - _Requirements: 3.5, 5.4_

- [-] 10. Update API Gateway and deployment configuration
  - [ ] 10.1 Update API Gateway specification
    - Add new WhatsApp reminder endpoints to instal-api.yaml
    - Configure function IDs for new reminder functions
    - Update CORS settings for new endpoints
    - _Requirements: 6.1, 6.2_

  - [ ] 10.2 Deploy and configure backend functions
    - Deploy send-auto-reminders function to Yandex Cloud
    - Deploy send-manual-reminder function to Yandex Cloud
    - Configure environment variables for Green API integration
    - Set up cron trigger for automatic reminder function
    - Update function deployment scripts
    - _Requirements: 1.2, 2.2, 6.1_

- [ ] 11. Create comprehensive testing suite
  - [ ] 11.1 Implement backend function tests
    - Create unit tests for template variable substitution
    - Test date calculation logic for due date detection
    - Mock Green API responses for integration testing
    - Test error handling scenarios and retry logic
    - _Requirements: 1.1, 2.1, 8.2, 8.5_

  - [ ] 11.2 Implement frontend component tests
    - Test WhatsApp settings form validation and submission
    - Test template editor functionality and variable substitution
    - Test context menu interactions and bulk selection
    - Test error handling and user feedback mechanisms
    - _Requirements: 4.4, 4.5, 3.1, 7.1_