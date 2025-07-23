# Design Document

## Overview

This design enhances the WhatsApp integration UI in the Settings screen by implementing a progressive disclosure pattern. Instead of showing all configuration options at once, the interface will present a clean setup flow using dialogs for configuration, making the experience more intuitive and less overwhelming for users.

## Architecture

### Component Structure

```
SettingsScreen
├── WhatsAppIntegrationSection (new)
│   ├── WhatsAppSetupButton (when not configured)
│   └── WhatsAppManagementPanel (when configured)
│       ├── CredentialsButton
│       ├── TemplatesButton
│       └── AutoRemindersSwitch
└── Dialogs
    ├── WhatsAppSetupDialog (multi-step)
    │   ├── CredentialsStep
    │   └── TemplatesStep
    ├── WhatsAppCredentialsDialog
    └── WhatsAppTemplatesDialog
```

### State Management

The component will manage the following states:
- `isWhatsAppConfigured`: Boolean indicating if WhatsApp is set up
- `isWhatsAppEnabled`: Boolean for automatic reminders toggle
- `setupStep`: Current step in the setup dialog (credentials/templates)
- Dialog visibility states for each dialog type

## Components and Interfaces

### 1. WhatsAppIntegrationSection Widget

**Purpose**: Main container for WhatsApp integration UI in Settings screen

**Props**:
- `isConfigured`: Boolean
- `isEnabled`: Boolean
- `onSetupPressed`: Callback
- `onCredentialsPressed`: Callback
- `onTemplatesPressed`: Callback
- `onEnabledChanged`: Callback

**Visual Design**:
- Container with white background, 12px border radius
- 24px padding, AppTheme.borderColor border
- Header with WhatsApp icon and title
- Conditional content based on configuration state

### 2. WhatsAppSetupDialog Widget

**Purpose**: Multi-step dialog for initial WhatsApp setup

**Features**:
- Step 1: Credentials configuration with setup guide
- Step 2: Message templates configuration
- Progress indicator showing current step
- Navigation buttons (Back, Continue, Finish)

**Visual Design**:
- AlertDialog with 600px width, 500px height
- Header with progress indicator
- Content area with step-specific forms
- Footer with navigation buttons

### 3. WhatsAppCredentialsDialog Widget

**Purpose**: Standalone dialog for editing credentials

**Features**:
- Green API setup guide with links
- Instance ID and Token input fields
- Connection test functionality
- Save and Cancel buttons

### 4. WhatsAppTemplatesDialog Widget

**Purpose**: Standalone dialog for editing message templates

**Features**:
- Reuses existing WhatsAppTemplateEditor widget
- Save and Cancel buttons
- Full template editing capabilities

### 5. WhatsAppManagementPanel Widget

**Purpose**: Management interface shown when WhatsApp is configured

**Features**:
- Two action buttons: "Change Credentials" and "Change Templates"
- Automatic reminders switch with description
- Status indicators

## Data Models

### WhatsAppSettings Model

```dart
class WhatsAppSettings {
  final String greenApiInstanceId;
  final String greenApiToken;
  final String reminderTemplate7Days;
  final String reminderTemplateDueToday;
  final String reminderTemplateManual;
  final bool isEnabled;
  final bool isConfigured;
}
```

## Error Handling

### Connection Test Errors
- Network connectivity issues
- Invalid credentials
- Green API service unavailable
- Rate limiting

### Validation Errors
- Empty required fields
- Invalid instance ID format
- Token format validation
- Template validation errors

### Save Operation Errors
- Server communication failures
- Authentication errors
- Data persistence issues

## Testing Strategy

### Unit Tests
- WhatsApp settings validation logic
- Dialog state management
- API service integration
- Error handling scenarios

### Widget Tests
- Dialog rendering and navigation
- Form validation behavior
- Button interactions
- State updates

### Integration Tests
- Complete setup flow
- Settings persistence
- API communication
- Error recovery

## Implementation Details

### Setup Flow

1. **Initial State**: Show setup button when not configured
2. **Setup Dialog Step 1**: 
   - Display Green API setup guide
   - Collect credentials with validation
   - Test connection before proceeding
3. **Setup Dialog Step 2**:
   - Show default message templates
   - Allow customization
   - Validate templates
4. **Completion**:
   - Save all settings
   - Enable automatic reminders by default
   - Show management panel

### Management Interface

1. **Configured State**: Show management buttons and switch
2. **Credentials Management**: Open credentials dialog
3. **Templates Management**: Open templates dialog
4. **Reminders Toggle**: Immediate save on change

### Visual Consistency

- Use existing CustomButton, CustomTextField components
- Follow AppTheme color scheme and spacing
- Maintain 12px border radius throughout
- Use consistent 24px padding for containers
- Apply subtle shadows for depth

### Responsive Design

- Dialogs adapt to screen size
- Minimum and maximum dialog dimensions
- Proper spacing on different screen sizes
- Touch-friendly button sizes

### Accessibility

- Proper focus management in dialogs
- Screen reader support
- Keyboard navigation
- High contrast support
- Appropriate ARIA labels

### Performance Considerations

- Lazy loading of dialog content
- Efficient state updates
- Minimal re-renders
- Proper disposal of resources

## User Experience Flow

### First-Time Setup
1. User sees "Set Up WhatsApp Integration" button
2. Clicks button → Setup dialog opens
3. Reads setup guide, enters credentials
4. Tests connection → Success feedback
5. Clicks "Continue" → Templates step
6. Reviews/edits templates
7. Clicks "Finish" → Settings saved, dialog closes
8. Management panel appears with reminders enabled

### Ongoing Management
1. User sees management buttons and switch
2. Can toggle reminders instantly
3. Can edit credentials or templates via dialogs
4. Changes are saved immediately with feedback

### Error Recovery
1. Clear error messages with actionable guidance
2. Ability to retry failed operations
3. Graceful degradation when services unavailable
4. Preservation of user input during errors