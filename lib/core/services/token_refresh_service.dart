import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../api/api_client.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';

class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  factory TokenRefreshService() => _instance;
  TokenRefreshService._internal();

  final AuthLocalDataSource _authLocalDataSource = AuthLocalDataSourceImpl();
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  /// Initialize the token refresh service
  void initialize() {
    _startPeriodicRefresh();
    _setupAppLifecycleListener();
  }

  /// Start periodic token refresh check
  void _startPeriodicRefresh() {
    // Check every 2 minutes if token needs refresh
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkAndRefreshToken();
    });
  }

  /// Setup app lifecycle listener to refresh token when app resumes
  void _setupAppLifecycleListener() {
    if (!kIsWeb) {
      SystemChannels.lifecycle.setMessageHandler((message) async {
        if (message == AppLifecycleState.resumed.toString()) {
          // App resumed from background, check if token needs refresh
          await _checkAndRefreshToken();
        }
        return null;
      });
    }
  }

  /// Check if token needs refresh and refresh if necessary
  Future<void> _checkAndRefreshToken() async {
    if (_isRefreshing) return; // Prevent concurrent refresh attempts

    try {
      _isRefreshing = true;
      final authState = await _authLocalDataSource.getAuthState();

      if (!authState.isAuthenticated || authState.refreshToken == null) {
        return;
      }

      // Check if token is expired or needs refresh
      if (authState.isTokenExpired || authState.needsRefresh) {
        debugPrint('🔄 Token needs refresh, attempting automatic refresh...');
        
        try {
          // Use the API client's refresh mechanism by making a simple authenticated request
          // This will trigger the token refresh logic in the API client if needed
          await ApiClient.get('/clients?user_id=${authState.user?.id}&limit=1&offset=0');
          debugPrint('✅ Token refreshed successfully');
        } catch (e) {
          debugPrint('❌ Token refresh failed: $e');
          // Only clear auth state if it's a token expiration error
          if (e is TokenExpiredException || e is UnauthorizedException) {
            await _authLocalDataSource.clearAuthState();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking token: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manually trigger token refresh
  Future<bool> refreshToken() async {
    try {
      await _checkAndRefreshToken();
      final authState = await _authLocalDataSource.getAuthState();
      return authState.isAuthenticated && !authState.isTokenExpired;
    } catch (e) {
      debugPrint('❌ Manual token refresh failed: $e');
      return false;
    }
  }

  /// Dispose the service
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}