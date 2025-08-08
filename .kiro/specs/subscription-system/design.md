# Design Document

## Overview

The subscription system will be implemented as a new feature module following the existing Clean Architecture pattern. It will integrate with the current authentication flow by adding a subscription guard that checks subscription status after successful authentication. The system uses a single database table approach with manual code generation and activation via Telegram communication.

## Architecture

### High-Level Flow
```
User Login/Register → AuthGuard → SubscriptionGuard → Main App
                                       ↓
                              Subscription Screen (if no active subscription)
```

### Component Integration
- **SubscriptionGuard**: New widget that wraps the main app content, similar to AuthGuard
- **Subscription Feature Module**: Complete feature following Clean Architecture
- **Backend Functions**: Two serverless functions for code validation and status checking
- **Database**: Single `subscription_codes` table in YDB

## Components and Interfaces

### 1. Database Schema

```sql
CREATE TABLE subscription_codes (
    code STRING PRIMARY KEY,
    subscription_type STRING,     -- 'trial', 'basic', 'pro'
    duration STRING,              -- 'monthly', 'yearly', '14days'
    user_telegram STRING,         -- user's telegram handle (optional)
    amount DECIMAL(10,2),
    created_date TIMESTAMP,
    activated_date TIMESTAMP,
    end_date TIMESTAMP,
    status STRING,                -- 'unused', 'active', 'expired'
    activated_by STRING           -- user_id who activated the code
);
```

### 2. Domain Layer

#### Entities
```dart
// lib/features/subscription/domain/entities/subscription.dart
class Subscription {
  final String code;
  final SubscriptionType type;
  final String duration;
  final String? userTelegram;
  final double amount;
  final DateTime createdDate;
  final DateTime? activatedDate;
  final DateTime? endDate;
  final SubscriptionStatus status;
  final String? activatedBy;
}

enum SubscriptionType { trial, basic, pro }
enum SubscriptionStatus { unused, active, expired }

// lib/features/subscription/domain/entities/subscription_state.dart
class SubscriptionState {
  final bool hasActiveSubscription;
  final List<Subscription> userSubscriptions;
  final SubscriptionType? currentType;
  final DateTime? currentEndDate;
  final UserSubscriptionStatus userStatus;
}

enum UserSubscriptionStatus { newUser, hasExpired, hasActive }
```

#### Repository Interface
```dart
// lib/features/subscription/domain/repositories/subscription_repository.dart
abstract class SubscriptionRepository {
  Future<Subscription> validateSubscriptionCode(String code, String userId);
  Future<SubscriptionState> checkSubscriptionStatus(String userId);
}
```

#### Use Cases
```dart
// lib/features/subscription/domain/usecases/validate_subscription_code.dart
class ValidateSubscriptionCode {
  Future<Subscription> call(String code, String userId);
}

// lib/features/subscription/domain/usecases/check_subscription_status.dart
class CheckSubscriptionStatus {
  Future<SubscriptionState> call(String userId);
}
```

### 3. Data Layer

#### Models
```dart
// lib/features/subscription/data/models/subscription_model.dart
class SubscriptionModel extends Subscription {
  // JSON serialization methods
  factory SubscriptionModel.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### Data Sources
```dart
// lib/features/subscription/data/datasources/subscription_remote_datasource.dart
abstract class SubscriptionRemoteDataSource {
  Future<SubscriptionModel> validateCode(String code, String userId);
  Future<List<SubscriptionModel>> getUserSubscriptions(String userId);
}

// lib/features/subscription/data/datasources/subscription_local_datasource.dart
abstract class SubscriptionLocalDataSource {
  Future<void> cacheSubscriptionState(SubscriptionState state);
  Future<SubscriptionState?> getCachedSubscriptionState(String userId);
  Future<void> clearSubscriptionCache(String userId);
}
```

### 4. Presentation Layer

#### Screens
```dart
// lib/features/subscription/presentation/screens/subscription_screen.dart
class SubscriptionScreen extends StatefulWidget {
  // Displays different content based on user subscription status
  // - New user: Welcome message with trial info
  // - Expired user: Renewal message
  // - Code input field and activation button
  // - Telegram contact information
}
```

#### Widgets
```dart
// lib/core/widgets/subscription_guard.dart
class SubscriptionGuard extends StatefulWidget {
  final Widget child;
  // Checks subscription status and shows SubscriptionScreen or main app
}

// lib/features/subscription/presentation/widgets/subscription_status_message.dart
class SubscriptionStatusMessage extends StatelessWidget {
  final UserSubscriptionStatus status;
  // Displays appropriate message based on user status
}
```

#### Providers
```dart
// lib/features/subscription/presentation/providers/subscription_provider.dart
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionState? _subscriptionState;
  bool _isLoading = false;
  String? _error;
  
  Future<void> validateCode(String code);
  Future<void> checkStatus();
  void clearError();
}
```

### 5. Backend Functions

#### validate-subscription-code Function
```python
# functions/validate-subscription-code/index.py
def handler(event, context):
    # Extract code and user_id from request
    # Validate code exists and is unused
    # Use server-side timestamp for activated_date
    # Calculate end_date based on server time + duration
    # Update code with activated_by, activated_date, end_date, status
    # Return subscription information with server-calculated dates
```

#### check-subscription-status Function
```python
# functions/check-subscription-status/index.py
def handler(event, context):
    # Extract user_id from request
    # Query all subscription codes for user
    # Use server-side current timestamp to check expiration
    # Update expired codes to 'expired' status if end_date < server_time
    # Determine current subscription state based on server time
    # Return subscription status and details
```

## Data Models

### Subscription Code Lifecycle
1. **Created**: Admin manually creates code in YDB with status 'unused'
2. **Activated**: User enters code, server calculates dates using server timestamp, status changes to 'active'
3. **Expired**: Server-side functions check expiration using server time (end_date < server_current_time) and update status accordingly

### Duration Calculation Logic
- **trial + 14days**: activated_date + 14 days
- **basic/pro + monthly**: activated_date + 30 days  
- **basic/pro + yearly**: activated_date + 365 days

**Important**: All date calculations and expiration checks are performed server-side using YDB/server timestamps to prevent client-side time manipulation. The client never determines subscription validity based on local device time.

### Multiple Subscription Handling
- Users can have multiple subscription codes
- Active status determined by ANY code being active and not expired
- Most recent active subscription determines current subscription type

## Error Handling

### Client-Side Error Scenarios
1. **Invalid Code**: Code doesn't exist or is malformed
2. **Already Used Code**: Code has already been activated by another user
3. **Network Errors**: API calls fail due to connectivity issues
4. **Expired Code**: Code exists but has already expired

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CODE",
    "message": "The subscription code is invalid or has already been used"
  }
}
```

### Error Handling Strategy
- Display user-friendly error messages in the subscription screen
- Implement retry logic for network failures
- Cache subscription state locally to handle offline scenarios
- Log errors for debugging while maintaining user privacy

## Testing Strategy

### Unit Tests
- **Domain Layer**: Test use cases and business logic
- **Data Layer**: Test repository implementations and data transformations
- **Presentation Layer**: Test providers and widget logic

### Integration Tests
- **API Integration**: Test backend function calls and responses
- **Database Integration**: Test subscription code lifecycle
- **Authentication Integration**: Test subscription guard with auth flow

### Widget Tests
- **SubscriptionScreen**: Test different message displays based on user status
- **SubscriptionGuard**: Test navigation logic based on subscription state
- **Form Validation**: Test code input validation and error display

### End-to-End Tests
- **Complete Flow**: Test from login through subscription activation to main app
- **Multiple Subscriptions**: Test handling of users with multiple codes
- **Expiration Scenarios**: Test behavior when subscriptions expire

## Integration Points

### Router Integration
The SubscriptionGuard will be integrated into the existing router structure:

```dart
// Modified app_router.dart structure
GoRoute(
  path: '/installments',
  pageBuilder: (context, state) => MaterialPage(
    child: AuthGuard(
      child: SubscriptionGuard(
        child: ResponsiveMainLayout(child: const InstallmentsListScreen()),
      ),
    ),
  ),
)
```

### Authentication Flow Integration
1. User completes login/register via existing AuthGuard
2. SubscriptionGuard checks subscription status
3. If no active subscription → show SubscriptionScreen
4. If active subscription → show main app content

### Localization Integration
- All subscription-related text will use the existing AppLocalizations system
- Support for Russian and other configured languages
- Localized error messages and user instructions

### Theme Integration
- Follow existing design patterns from `DESIGN_PATTERNS.md`
- Use consistent typography, colors, and spacing
- Responsive design for mobile and desktop platforms