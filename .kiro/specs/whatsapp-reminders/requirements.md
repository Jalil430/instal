# Requirements Document

## Introduction

The WhatsApp Reminders feature enables automatic and manual sending of payment reminders to clients via WhatsApp using Green API. The system will automatically send reminders when installments are due in 7 days and on the due date, while also providing manual reminder capabilities through the installments list interface. Users can customize reminder message templates with dynamic variables.

## Requirements

### Requirement 1

**User Story:** As a financial service provider, I want the system to automatically send WhatsApp reminders to clients when their installments are due in 7 days, so that clients are proactively notified about upcoming payments.

#### Acceptance Criteria

1. WHEN an installment due date is exactly 7 days away THEN the system SHALL send a WhatsApp reminder to the client's phone number
2. WHEN the daily cron job runs at 9:00 AM THEN the system SHALL check all installments for 7-day due date matches
3. WHEN sending a 7-day reminder THEN the system SHALL use the configured reminder template with client-specific variables
4. IF a client has multiple installments due in 7 days THEN the system SHALL send separate reminders for each installment
5. WHEN a reminder is sent successfully THEN the system SHALL log the reminder activity

### Requirement 2

**User Story:** As a financial service provider, I want the system to automatically send WhatsApp reminders to clients on their installment due date, so that clients receive timely payment notifications.

#### Acceptance Criteria

1. WHEN an installment due date is today THEN the system SHALL send a WhatsApp reminder to the client's phone number
2. WHEN the daily cron job runs at 9:00 AM THEN the system SHALL check all installments for today's due date matches
3. WHEN sending a due date reminder THEN the system SHALL use the configured due date template with client-specific variables
4. IF a client has multiple installments due today THEN the system SHALL send separate reminders for each installment
5. WHEN a reminder is sent successfully THEN the system SHALL log the reminder activity

### Requirement 3

**User Story:** As a financial service provider, I want to manually send WhatsApp reminders to specific clients from the installments list, so that I can send immediate notifications when needed.

#### Acceptance Criteria

1. WHEN I right-click on an installment item in the installments list THEN the system SHALL display a context menu with "Send WhatsApp Reminder" option
2. WHEN I select "Send WhatsApp Reminder" THEN the system SHALL immediately send a WhatsApp message to the client
3. WHEN sending a manual reminder THEN the system SHALL use the configured manual reminder template with installment-specific variables
4. WHEN a manual reminder is sent successfully THEN the system SHALL show a success notification
5. IF the manual reminder fails to send THEN the system SHALL show an error message with the failure reason

### Requirement 4

**User Story:** As a financial service provider, I want to configure custom WhatsApp reminder message templates with dynamic variables, so that I can personalize messages for my clients.

#### Acceptance Criteria

1. WHEN I access the settings screen THEN the system SHALL display WhatsApp reminder configuration options
2. WHEN configuring reminder templates THEN the system SHALL support variables like {client_name}, {installment_amount}, {due_date}, {days_remaining}
3. WHEN I save reminder template changes THEN the system SHALL validate the template format and save the configuration
4. WHEN displaying template configuration THEN the system SHALL show available variables and their descriptions
5. IF I enter an invalid template format THEN the system SHALL show validation errors

### Requirement 5

**User Story:** As a financial service provider, I want to configure Green API credentials in the settings, so that the system can connect to WhatsApp messaging service.

#### Acceptance Criteria

1. WHEN I access WhatsApp settings THEN the system SHALL display fields for Green API instance ID and token
2. WHEN I save Green API credentials THEN the system SHALL securely store the credentials
3. WHEN testing the connection THEN the system SHALL verify the Green API credentials are valid
4. IF the Green API credentials are invalid THEN the system SHALL show an error message
5. WHEN credentials are not configured THEN the system SHALL disable WhatsApp reminder functionality

### Requirement 6

**User Story:** As a system administrator, I want the backend to have separate functions for automatic and manual reminder sending, so that the system can handle different reminder scenarios efficiently.

#### Acceptance Criteria

1. WHEN the cron trigger executes THEN the system SHALL call the automatic reminder function
2. WHEN a manual reminder is requested THEN the system SHALL call the manual reminder function with specific installment ID or list of installment IDs
3. WHEN the automatic function runs THEN the system SHALL query installments due in 7 days and today and send reminders to all matching clients
4. WHEN the manual function runs THEN the system SHALL send reminders for the specified installment(s) immediately
5. WHEN processing multiple installments THEN the system SHALL handle each reminder independently and continue processing even if individual reminders fail
6. WHEN either function completes THEN the system SHALL return appropriate success or error responses with details for each processed installment

### Requirement 7

**User Story:** As a financial service provider, I want to send WhatsApp reminders to multiple selected installments at once, so that I can efficiently notify multiple clients simultaneously.

#### Acceptance Criteria

1. WHEN I select multiple installments in the installments list THEN the system SHALL enable bulk reminder actions
2. WHEN I choose to send bulk reminders THEN the system SHALL send WhatsApp messages to all selected installments' clients
3. WHEN processing bulk reminders THEN the system SHALL handle each reminder independently and show progress status
4. WHEN bulk reminders complete THEN the system SHALL show a summary of successful and failed reminder attempts
5. IF some bulk reminders fail THEN the system SHALL continue processing remaining reminders and report individual failures

### Requirement 8

**User Story:** As a financial service provider, I want the system to handle WhatsApp messaging errors gracefully, so that failed reminders don't disrupt the application.

#### Acceptance Criteria

1. WHEN a WhatsApp message fails to send THEN the system SHALL log the error details
2. WHEN Green API is unavailable THEN the system SHALL retry the message up to 3 times
3. WHEN a client's phone number is invalid THEN the system SHALL log the invalid number and skip sending
4. WHEN API rate limits are exceeded THEN the system SHALL queue messages for later delivery
5. IF all retry attempts fail THEN the system SHALL log the permanent failure and continue processing other reminders