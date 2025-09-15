import 'package:flutter/foundation.dart';
import '../../domain/entities/subscription_state.dart';
import '../../domain/usecases/validate_subscription_code.dart';
import '../../domain/usecases/check_subscription_status.dart';
import '../../domain/exceptions/subscription_exceptions.dart';

class SubscriptionProvider extends ChangeNotifier {
  final ValidateSubscriptionCode _validateSubscriptionCode;
  final CheckSubscriptionStatus _checkSubscriptionStatus;

  SubscriptionState? _subscriptionState;
  bool _isLoading = false;
  String? _error;
  bool _isValidatingCode = false;

  SubscriptionProvider({
    required ValidateSubscriptionCode validateSubscriptionCode,
    required CheckSubscriptionStatus checkSubscriptionStatus,
  })  : _validateSubscriptionCode = validateSubscriptionCode,
        _checkSubscriptionStatus = checkSubscriptionStatus;

  // Getters
  SubscriptionState? get subscriptionState => _subscriptionState;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isValidatingCode => _isValidatingCode;
  bool get hasActiveSubscription => _subscriptionState?.hasActiveSubscription ?? false;
  UserSubscriptionStatus get userStatus => 
      _subscriptionState?.userStatus ?? UserSubscriptionStatus.newUser;

  /// Validates and activates a subscription code
  ///
  /// On success: optimistically marks subscription as active immediately
  /// and triggers a silent background status refresh. Any transient
  /// network error during the refresh no longer blocks app access.
  Future<bool> validateCode(String code, String userId) async {
    if (code.trim().isEmpty) {
      _setError('subscriptionCodeRequired');
      return false;
    }

    _setValidatingCode(true);
    _clearError();

    try {
      final activated = await _validateSubscriptionCode(code.trim(), userId);

      // Optimistic state: immediately mark as active so guards can proceed
      _setSubscriptionState(
        SubscriptionState(
          hasActiveSubscription: true,
          userSubscriptions: [activated],
          currentType: activated.type,
          currentEndDate: activated.endDate,
          userStatus: UserSubscriptionStatus.hasActive,
        ),
      );

      _setValidatingCode(false);

      // Fire-and-forget silent refresh to reconcile full state
      // Do not block success or surface errors to UI here
      // to avoid transient network failures preventing entry.
      // ignore: unawaited_futures
      checkStatus(userId, silent: true);

      return true;
    } on InvalidCodeException {
      _setError('subscriptionErrorInvalidCode');
    } on CodeAlreadyUsedException {
      _setError('subscriptionErrorCodeUsed');
    } on ExpiredCodeException {
      _setError('subscriptionErrorCodeExpired');
    } on NetworkException {
      // Fallback: activation may have succeeded server-side but response failed.
      // Try to fetch current status; if active, proceed as success.
      try {
        final state = await _checkSubscriptionStatus.call(userId);
        if (state.hasActiveSubscription) {
          _setSubscriptionState(state);
          _setValidatingCode(false);
          return true;
        }
      } catch (_) {
        // Ignore and surface original network error below
      }
      _setError('subscriptionErrorNetwork');
    } on ArgumentError {
      _setError('subscriptionCodeRequired');
    } catch (e) {
      _setError('subscriptionErrorUnexpected');
    }

    _setValidatingCode(false);
    return false;
  }

  /// Checks the current subscription status for a user
  Future<SubscriptionState?> checkStatus(String userId, {bool silent = false}) async {
    if (!silent) {
      _setLoading(true);
      _clearError();
    }

    try {
      final state = await _checkSubscriptionStatus.call(userId);
      _setSubscriptionState(state);
      if (!silent) {
        _setLoading(false);
      }
      return state;
    } on NetworkException {
      if (!silent) {
        _setError('subscriptionErrorNetwork');
      }
    } on ArgumentError {
      if (!silent) {
        _setError('subscriptionErrorUnexpected');
      }
    } catch (e, st) {
      if (!silent) {
        _setError('subscriptionErrorCheckFailed');
      }
    }

    if (!silent) {
      _setLoading(false);
    }
    return null;
  }

  /// Clears any error messages
  void clearError() {
    _clearError();
  }

  /// Resets the provider state
  void reset() {
    _subscriptionState = null;
    _isLoading = false;
    _error = null;
    _isValidatingCode = false;
    notifyListeners();
  }

  // Private methods
  void _setSubscriptionState(SubscriptionState state) {
    _subscriptionState = state;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setValidatingCode(bool validating) {
    _isValidatingCode = validating;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Debug helper
  void debugDump([String tag = '']) {}


}
