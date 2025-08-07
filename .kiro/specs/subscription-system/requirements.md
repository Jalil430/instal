# Requirements Document

## Introduction

This feature implements a subscription system for the Instal app using manual activation codes. The system allows users to activate subscription codes sent via Telegram to gain access to the application. It supports different subscription types (trial, basic, pro) with varying durations and handles multiple subscription scenarios for users.

## Requirements

### Requirement 1

**User Story:** As a new user, I want to see a subscription screen after login/register that explains how to get access to the app, so that I understand the process to activate my subscription.

#### Acceptance Criteria

1. WHEN a user completes login or registration AND has no subscription codes tied to their user_id THEN the system SHALL display a subscription screen with new user messaging
2. WHEN displaying new user messaging THEN the system SHALL show information about contacting the admin on Telegram for a 14-day free trial
3. WHEN displaying the subscription screen THEN the system SHALL provide a code input field and activate button
4. WHEN displaying the subscription screen THEN the system SHALL show the admin's Telegram contact information

### Requirement 2

**User Story:** As a user with expired subscriptions, I want to see appropriate messaging on the subscription screen, so that I know my previous subscription has expired and I need to renew.

#### Acceptance Criteria

1. WHEN a user has subscription codes tied to their user_id AND all subscriptions have status 'expired' THEN the system SHALL display a subscription screen with expired user messaging
2. WHEN displaying expired user messaging THEN the system SHALL indicate that their previous subscription has expired
3. WHEN displaying expired user messaging THEN the system SHALL provide information about renewing their subscription
4. WHEN displaying the subscription screen for expired users THEN the system SHALL still provide the code input field and activate button

### Requirement 3

**User Story:** As a user, I want to activate subscription codes by entering them in the app, so that I can gain access to the application features.

#### Acceptance Criteria

1. WHEN a user enters a valid unused subscription code THEN the system SHALL activate the code and update its status to 'active'
2. WHEN activating a subscription code THEN the system SHALL set the activated_by field to the current user's user_id
3. WHEN activating a subscription code THEN the system SHALL set the activated_date to the current timestamp
4. WHEN activating a subscription code THEN the system SHALL calculate and set the end_date based on the subscription duration
5. WHEN a user enters an invalid or already used code THEN the system SHALL display an appropriate error message
6. WHEN code activation is successful THEN the system SHALL redirect the user to the main application

### Requirement 4

**User Story:** As a user with an active subscription, I want to access the main application directly after login, so that I don't see the subscription screen unnecessarily.

#### Acceptance Criteria

1. WHEN a user logs in AND has at least one subscription code with status 'active' AND the end_date is in the future THEN the system SHALL bypass the subscription screen
2. WHEN determining active subscription status THEN the system SHALL check all subscription codes where activated_by equals the user's user_id
3. WHEN a user has multiple subscription codes THEN the system SHALL consider the subscription active if any code has status 'active' and end_date in the future
4. WHEN bypassing the subscription screen THEN the system SHALL navigate directly to the main application

### Requirement 5

**User Story:** As a system, I want to handle multiple subscription codes per user correctly, so that users can have sequential or overlapping subscriptions.

#### Acceptance Criteria

1. WHEN a user activates multiple subscription codes THEN the system SHALL allow multiple codes to be tied to the same user_id
2. WHEN checking subscription status THEN the system SHALL evaluate all codes associated with the user_id
3. WHEN multiple active subscriptions exist THEN the system SHALL consider the user as having an active subscription
4. WHEN all subscription codes for a user are expired THEN the system SHALL treat the user as having expired subscriptions

### Requirement 6

**User Story:** As a backend system, I want to provide API endpoints for subscription management, so that the Flutter app can validate codes and check subscription status.

#### Acceptance Criteria

1. WHEN the validate-subscription-code endpoint is called with a valid code and user_id THEN the system SHALL activate the code and return subscription information
2. WHEN the validate-subscription-code endpoint is called with an invalid code THEN the system SHALL return an error response
3. WHEN the check-subscription-status endpoint is called with a user_id THEN the system SHALL return the current subscription status and details
4. WHEN checking subscription status THEN the system SHALL return information about all subscription codes tied to the user_id
5. WHEN activating a code THEN the system SHALL calculate the correct end_date based on subscription_type and duration

### Requirement 7

**User Story:** As a user, I want the subscription system to support different subscription types and durations, so that I can have trial, basic, or pro access with appropriate time periods.

#### Acceptance Criteria

1. WHEN a subscription code has type 'trial' THEN the system SHALL provide 14 days of pro-level access
2. WHEN a subscription code has type 'basic' or 'pro' with duration 'monthly' THEN the system SHALL provide 30 days of access
3. WHEN a subscription code has type 'basic' or 'pro' with duration 'yearly' THEN the system SHALL provide 365 days of access
4. WHEN calculating end_date THEN the system SHALL add the appropriate number of days to the activation date
5. WHEN a trial subscription is active THEN the system SHALL provide the same access level as pro subscription