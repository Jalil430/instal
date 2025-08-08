import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_state.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/exceptions/subscription_exceptions.dart';
import '../datasources/subscription_remote_datasource.dart';
import '../datasources/subscription_local_datasource.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;
  final SubscriptionLocalDataSource localDataSource;

  const SubscriptionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Subscription> validateSubscriptionCode(String code, String userId) async {
    try {
      // Always validate codes remotely to ensure server-side validation
      final subscription = await remoteDataSource.validateCode(code, userId);
      
      // Clear any cached subscription state since it's now outdated
      await localDataSource.clearSubscriptionCache(userId);
      
      return subscription;
    } catch (e) {
      // Re-throw subscription exceptions as-is
      if (e is SubscriptionException) {
        rethrow;
      }
      // Convert other exceptions to NetworkException
      throw const NetworkException('Failed to validate subscription code');
    }
  }

  @override
  Future<SubscriptionState> checkSubscriptionStatus(String userId) async {
    try {
      // Remote-first to prevent stale cache keeping user on the subscription screen
      final subscriptions = await remoteDataSource.getUserSubscriptions(userId);
      // Normalize to base entity list to avoid generic variance/runtime type issues
      final baseSubscriptions = subscriptions.map<Subscription>((s) => s).toList(growable: false);
      final subscriptionState = _determineSubscriptionState(baseSubscriptions);
      // Best-effort cache; do not fail the flow if caching throws
      try {
        await localDataSource.cacheSubscriptionState(userId, subscriptionState);
      } catch (_) {}
      return subscriptionState;
    } catch (e, st) {
      // If there's an error fetching remote data, try to return cached data even if expired
      final cachedState = await localDataSource.getCachedSubscriptionState(userId);
      if (cachedState != null) {
        return cachedState;
      }
      
      // If no cached data and remote fails, re-throw or convert to NetworkException
      if (e is SubscriptionException) {
        rethrow;
      }
      throw const NetworkException('Failed to check subscription status');
    }
  }

  SubscriptionState _determineSubscriptionState(List<Subscription> subscriptions) {
    // Debug removed
    if (subscriptions.isEmpty) {
      // New user with no subscriptions
      return const SubscriptionState(
        hasActiveSubscription: false,
        userSubscriptions: [],
        currentType: null,
        currentEndDate: null,
        userStatus: UserSubscriptionStatus.newUser,
      );
    }

    // Find active subscriptions (server already handles expiration checking)
    final now = DateTime.now().toUtc();
    final activeSubscriptions = subscriptions
        .where((sub) {
          if (sub.status != SubscriptionStatus.active) return false;
          // Extra safety: ensure endDate is in the future
          if (sub.endDate == null) return true;
          // Compare in UTC to avoid timezone drift
          final subEndUtc = sub.endDate!.toUtc();
          final isActive = subEndUtc.isAfter(now) || subEndUtc.isAtSameMomentAs(now);
          return isActive;
        })
        .toList(growable: false);
    // ignore: avoid_print
    print('SubscriptionRepo: active after filter=${activeSubscriptions.length}');

    if (activeSubscriptions.isNotEmpty) {
      // User has active subscription(s)
      // Find the subscription with the latest end date
      final latestSubscription = activeSubscriptions.reduce((Subscription a, Subscription b) {
        if (a.endDate == null) return b;
        if (b.endDate == null) return a;
        return a.endDate!.isAfter(b.endDate!) ? a : b;
      });

      return SubscriptionState(
        hasActiveSubscription: true,
        userSubscriptions: subscriptions,
        currentType: latestSubscription.type,
        currentEndDate: latestSubscription.endDate,
        userStatus: UserSubscriptionStatus.hasActive,
      );
    } else {
      // User has subscriptions but all are expired or unused
      final hasExpiredSubscriptions = subscriptions
          .any((sub) => sub.status == SubscriptionStatus.expired);

      return SubscriptionState(
        hasActiveSubscription: false,
        userSubscriptions: subscriptions,
        currentType: null,
        currentEndDate: null,
        userStatus: hasExpiredSubscriptions 
            ? UserSubscriptionStatus.hasExpired 
            : UserSubscriptionStatus.newUser,
      );
    }
  }
}