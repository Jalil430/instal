# Implementation Plan

- [x] 1. Create WhatsApp integration section widget
  - Create WhatsAppIntegrationSection widget that conditionally shows setup button or management panel
  - Implement clean container styling with proper spacing and borders
  - Add WhatsApp icon and section title
  - _Requirements: 1.1, 1.3, 5.1, 5.5_

- [x] 2. Implement WhatsApp setup dialog with multi-step flow
  - [x] 2.1 Create WhatsAppSetupDialog widget with step navigation
    - Build AlertDialog with proper sizing and styling
    - Implement step indicator and navigation controls
    - Add progress tracking between credentials and templates steps
    - _Requirements: 2.1, 2.5, 5.2_

  - [x] 2.2 Create credentials setup step with guide
    - Add Green API setup guide with clear instructions
    - Implement credential input fields with validation
    - Add connection test functionality with feedback
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 2.3 Create templates setup step
    - Integrate existing WhatsAppTemplateEditor widget
    - Add default template population
    - Implement template validation and preview
    - _Requirements: 2.4, 2.5_

- [x] 3. Create management panel for configured WhatsApp integration
  - [x] 3.1 Build WhatsAppManagementPanel widget
    - Create container with two management buttons
    - Add automatic reminders switch with description
    - Implement proper spacing and visual hierarchy
    - _Requirements: 3.1, 4.1, 4.2_

  - [x] 3.2 Implement credentials management dialog
    - Create standalone WhatsAppCredentialsDialog
    - Reuse credential input and validation logic
    - Add save/cancel functionality with proper feedback
    - _Requirements: 3.2, 3.4_

  - [x] 3.3 Implement templates management dialog
    - Create standalone WhatsAppTemplatesDialog
    - Integrate WhatsAppTemplateEditor widget
    - Add save/cancel functionality with validation
    - _Requirements: 3.3, 3.4_

- [x] 4. Integrate new components into Settings screen
  - Replace existing messy WhatsApp section with new WhatsAppIntegrationSection
  - Remove old form fields and complex conditional rendering
  - Update state management to work with new component structure
  - _Requirements: 1.1, 3.1, 4.1_

- [ ] 5. Implement setup completion and state management
  - [x] 5.1 Handle setup completion flow
    - Save all settings when setup is finished
    - Automatically enable reminders after successful setup
    - Update UI state to show management panel
    - _Requirements: 2.5, 4.2_

  - [x] 5.2 Implement automatic reminders toggle
    - Add immediate save functionality for switch changes
    - Provide visual feedback for toggle state
    - Handle toggle state when WhatsApp is not properly configured
    - _Requirements: 4.2, 4.3, 4.4_

- [ ] 6. Add error handling and user feedback
  - Implement proper error messages for setup failures
  - Add success feedback for completed operations
  - Handle network errors and API failures gracefully
  - Add loading states for async operations
  - _Requirements: 2.2, 2.3, 3.4_

- [ ] 7. Apply consistent styling and theming
  - Ensure all components use AppTheme constants for colors and spacing
  - Apply consistent border radius (12px) and padding (24px)
  - Use proper font sizes and weights throughout
  - Add subtle shadows and hover effects where appropriate
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [ ] 8. Test and refine user experience
  - Test complete setup flow from start to finish
  - Verify management panel functionality
  - Test error scenarios and recovery
  - Ensure responsive behavior on different screen sizes
  - _Requirements: 1.1, 2.1, 2.5, 3.1, 4.1_