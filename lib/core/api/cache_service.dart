class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  
  // Cache duration - 2 minutes for most data
  static const Duration _defaultCacheDuration = Duration(minutes: 2);

  void set(String key, dynamic value, {Duration? duration}) {
    final expiry = DateTime.now().add(duration ?? _defaultCacheDuration);
    _cache[key] = CacheEntry(value, expiry);
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
  static String installmentsKey(String userId) => 'installments_$userId';
  static String paymentsKey(String installmentId) => 'payments_$installmentId';
  static String analyticsKey(String userId) => 'analytics_$userId';
  static String clientKey(String clientId) => 'client_$clientId';
  static String investorKey(String investorId) => 'investor_$investorId';
  static String installmentKey(String installmentId) => 'installment_$installmentId';
}

class CacheEntry {
  final dynamic value;
  final DateTime expiry;

  CacheEntry(this.value, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
} 