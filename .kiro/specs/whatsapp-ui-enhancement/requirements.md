# Requirements Document

## Introduction

This feature enhances the WhatsApp integration UI in the Settings screen to provide a cleaner, more intuitive user experience. The current implementation has a messy interface with all configuration options visible at once. The enhanced UI will use a progressive disclosure pattern with dialogs for setup and configuration, making the interface cleaner and more user-friendly.

## Requirements

### Requirement 1

**User Story:** As a user who hasn't set up WhatsApp integration, I want to see a simple setup button so that I can easily initiate the integration process.

#### Acceptance Criteria

1. WHEN the user has not configured WhatsApp integration THEN the system SHALL display only a single "Set Up WhatsApp Integration" button in the WhatsApp section
2. WHEN the user clicks the setup button THEN the system SHALL open a setup dialog with credentials configuration
3. IF WhatsApp is not configured THEN the system SHALL hide all other WhatsApp-related controls

### Requirement 2

**User Story:** As a user setting up WhatsApp integration, I want a guided setup process so that I can easily configure my Green API credentials and message templates.

#### Acceptance Criteria

1. WHEN the setup dialog opens THEN the system SHALL display a guide explaining how to get Green API credentials
2. WHEN the user enters credentials THEN the system SHALL validate the input format before allowing continuation
3. WHEN the user clicks "Continue" with valid credentials THEN the system SHALL open a second dialog for message template configuration
4. WHEN the user completes template configuration THEN the system SHALL save all settings and enable automatic reminders by default
5. WHEN setup is completed THEN the system SHALL close the dialogs and update the WhatsApp section UI

### Requirement 3

**User Story:** As a user with configured WhatsApp integration, I want to see management options so that I can modify my credentials or templates when needed.

#### Acceptance Criteria

1. WHEN WhatsApp integration is configured THEN the system SHALL display two management buttons: "Change Credentials" and "Change Message Templates"
2. WHEN the user clicks "Change Credentials" THEN the system SHALL open the credentials configuration dialog
3. WHEN the user clicks "Change Message Templates" THEN the system SHALL open the templates configuration dialog
4. WHEN the user saves changes in either dialog THEN the system SHALL update the settings and show a success message

### Requirement 4

**User Story:** As a user with configured WhatsApp integration, I want to easily control automatic reminders so that I can enable or disable them as needed.

#### Acceptance Criteria

1. WHEN WhatsApp integration is configured THEN the system SHALL display a switch for automatic reminders below the management buttons
2. WHEN setup is completed THEN the system SHALL automatically enable the automatic reminders switch
3. WHEN the user toggles the switch THEN the system SHALL immediately save the preference
4. WHEN automatic reminders are disabled THEN the system SHALL show appropriate visual feedback

### Requirement 5

**User Story:** As a user, I want the WhatsApp integration UI to match the app's design system so that it feels consistent with the rest of the application.

#### Acceptance Criteria

1. WHEN displaying WhatsApp UI elements THEN the system SHALL use consistent styling with white backgrounds, AppTheme.surfaceColor containers, and AppTheme.borderColor borders
2. WHEN showing dialogs THEN the system SHALL use AlertDialog with rounded corners, proper padding, and consistent button styling
3. WHEN displaying buttons THEN the system SHALL use CustomButton components with AppTheme.primaryColor and proper sizing
4. WHEN showing form fields THEN the system SHALL use CustomTextField components with white backgrounds and AppTheme.borderColor borders
5. WHEN displaying containers THEN the system SHALL use 12px border radius, 24px padding, and subtle shadows consistent with existing screens
6. WHEN showing text THEN the system SHALL use consistent font sizes (16px for headers, 14px for body, 12px for labels) and AppTheme color constants