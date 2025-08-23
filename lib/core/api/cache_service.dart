class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  
  // Optimized cache durations based on data volatility
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  static const Duration _listCacheDuration = Duration(minutes: 3);
  static const Duration _detailCacheDuration = Duration(minutes: 10);
  static const Duration _analyticsCacheDuration = Duration(minutes: 15);

  void set(String key, dynamic value, {Duration? duration}) {
    final expiry = DateTime.now().add(duration ?? _defaultCacheDuration);
    _cache[key] = CacheEntry(value, expiry);
  }

  // Smart cache invalidation - only invalidate related data
  void invalidateRelated(String entityType, String userId) {
    final keysToRemove = <String>[];
    
    switch (entityType) {
      case 'client':
        // Remove client-related caches
        keysToRemove.addAll(getKeysWithPrefix('clients_$userId'));
        keysToRemove.addAll(getKeysWithPrefix('client_'));
        keysToRemove.addAll(getKeysWithPrefix('analytics_$userId'));
        break;
      case 'investor':
        keysToRemove.addAll(getKeysWithPrefix('investors_$userId'));
        keysToRemove.addAll(getKeysWithPrefix('investor_'));
        keysToRemove.addAll(getKeysWithPrefix('analytics_$userId'));
        break;
      case 'installment':
        keysToRemove.addAll(getKeysWithPrefix('installments_$userId'));
        keysToRemove.addAll(getKeysWithPrefix('installment_'));
        keysToRemove.addAll(getKeysWithPrefix('analytics_$userId'));
        break;
      case 'wallet':
        keysToRemove.addAll(getKeysWithPrefix('wallets_$userId'));
        keysToRemove.addAll(getKeysWithPrefix('wallet_'));
        keysToRemove.addAll(getKeysWithPrefix('analytics_$userId'));
        break;
    }
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  // Clear expired entries
  void cleanup() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  // Get all cache keys matching a prefix pattern
  List<String> getKeysWithPrefix(String prefix) {
    return _cache.keys.where((key) => key.startsWith(prefix)).toList();
  }

  // Cache key generators
  static String clientsKey(String userId) => 'clients_$userId';
  static String investorsKey(String userId) => 'investors_$userId';
  static String walletsKey(String userId) => 'wallets_$userId';
  static String installmentsKey(String userId) => 'installments_$userId';
  static String paymentsKey(String installmentId) => 'payments_$installmentId';
  static String analyticsKey(String userId) => 'analytics_$userId';
  static String clientKey(String clientId) => 'client_$clientId';
  static String investorKey(String investorId) => 'investor_$investorId';
  static String walletKey(String walletId) => 'wallet_$walletId';
  static String installmentKey(String installmentId) => 'installment_$installmentId';
}

class CacheEntry {
  final dynamic value;
  final DateTime expiry;

  CacheEntry(this.value, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
} 