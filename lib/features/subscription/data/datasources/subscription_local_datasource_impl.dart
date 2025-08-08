import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/subscription_state.dart';
import '../../domain/entities/subscription.dart';
import '../models/subscription_model.dart';
import 'subscription_local_datasource.dart';

class SubscriptionLocalDataSourceImpl implements SubscriptionLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _cachePrefix = 'subscription_state_';
  static const String _cacheTimestampPrefix = 'subscription_timestamp_';
  static const int _cacheExpirationMinutes = 5; // Cache expires after 5 minutes

  const SubscriptionLocalDataSourceImpl({
    required this.sharedPreferences,
  });

  @override
  Future<void> cacheSubscriptionState(String userId, SubscriptionState state) async {
    final cacheKey = _cachePrefix + userId;
    final timestampKey = _cacheTimestampPrefix + userId;
    
    final stateJson = _subscriptionStateToJson(state);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await Future.wait([
      sharedPreferences.setString(cacheKey, jsonEncode(stateJson)),
      sharedPreferences.setInt(timestampKey, timestamp),
    ]);
  }

  @override
  Future<SubscriptionState?> getCachedSubscriptionState(String userId) async {
    final cacheKey = _cachePrefix + userId;
    final timestampKey = _cacheTimestampPrefix + userId;
    
    final cachedData = sharedPreferences.getString(cacheKey);
    final timestamp = sharedPreferences.getInt(timestampKey);
    
    if (cachedData == null || timestamp == null) {
      return null;
    }
    
    // Check if cache has expired
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final expirationTime = cacheTime.add(const Duration(minutes: _cacheExpirationMinutes));
    
    if (DateTime.now().isAfter(expirationTime)) {
      // Cache has expired, clear it
      await clearSubscriptionCache(userId);
      return null;
    }
    
    try {
      final stateJson = jsonDecode(cachedData) as Map<String, dynamic>;
      return _subscriptionStateFromJson(stateJson);
    } catch (e) {
      // If there's an error parsing cached data, clear it
      await clearSubscriptionCache(userId);
      return null;
    }
  }

  @override
  Future<void> clearSubscriptionCache(String userId) async {
    final cacheKey = _cachePrefix + userId;
    final timestampKey = _cacheTimestampPrefix + userId;
    
    await Future.wait([
      sharedPreferences.remove(cacheKey),
      sharedPreferences.remove(timestampKey),
    ]);
  }

  @override
  Future<void> clearAllCache() async {
    final keys = sharedPreferences.getKeys();
    final subscriptionKeys = keys.where((key) => 
        key.startsWith(_cachePrefix) || key.startsWith(_cacheTimestampPrefix));
    
    await Future.wait(
      subscriptionKeys.map((key) => sharedPreferences.remove(key)),
    );
  }

  Map<String, dynamic> _subscriptionStateToJson(SubscriptionState state) {
    return {
      'hasActiveSubscription': state.hasActiveSubscription,
      'userSubscriptions': state.userSubscriptions
          .map((sub) => SubscriptionModel.fromEntity(sub).toJson())
          .toList(),
      'currentType': state.currentType != null 
          ? _subscriptionTypeToString(state.currentType!)
          : null,
      'currentEndDate': state.currentEndDate?.toIso8601String(),
      'userStatus': _userSubscriptionStatusToString(state.userStatus),
    };
  }

  SubscriptionState _subscriptionStateFromJson(Map<String, dynamic> json) {
    final subscriptionsJson = json['userSubscriptions'] as List<dynamic>;
    final subscriptions = subscriptionsJson
        .map((subJson) => SubscriptionModel.fromJson(subJson as Map<String, dynamic>))
        .toList();

    return SubscriptionState(
      hasActiveSubscription: json['hasActiveSubscription'] as bool,
      userSubscriptions: subscriptions,
      currentType: json['currentType'] != null 
          ? _parseSubscriptionType(json['currentType'] as String)
          : null,
      currentEndDate: json['currentEndDate'] != null 
          ? DateTime.parse(json['currentEndDate'] as String)
          : null,
      userStatus: _parseUserSubscriptionStatus(json['userStatus'] as String),
    );
  }

  String _subscriptionTypeToString(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.trial:
        return 'trial';
      case SubscriptionType.basic:
        return 'basic';
      case SubscriptionType.pro:
        return 'pro';
    }
  }

  SubscriptionType _parseSubscriptionType(String type) {
    switch (type.toLowerCase()) {
      case 'trial':
        return SubscriptionType.trial;
      case 'basic':
        return SubscriptionType.basic;
      case 'pro':
        return SubscriptionType.pro;
      default:
        throw ArgumentError('Unknown subscription type: $type');
    }
  }

  String _userSubscriptionStatusToString(UserSubscriptionStatus status) {
    switch (status) {
      case UserSubscriptionStatus.newUser:
        return 'newUser';
      case UserSubscriptionStatus.hasExpired:
        return 'hasExpired';
      case UserSubscriptionStatus.hasActive:
        return 'hasActive';
    }
  }

  UserSubscriptionStatus _parseUserSubscriptionStatus(String status) {
    switch (status) {
      case 'newUser':
        return UserSubscriptionStatus.newUser;
      case 'hasExpired':
        return UserSubscriptionStatus.hasExpired;
      case 'hasActive':
        return UserSubscriptionStatus.hasActive;
      default:
        throw ArgumentError('Unknown user subscription status: $status');
    }
  }
}