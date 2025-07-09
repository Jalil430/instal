import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<AuthState> getAuthState();
  Future<void> saveAuthState(AuthState authState);
  Future<void> clearAuthState();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _userKey = 'current_user';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _expiresAtKey = 'expires_at';
  static const String _isAuthenticatedKey = 'is_authenticated';

  @override
  Future<AuthState> getAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final isAuthenticated = prefs.getBool(_isAuthenticatedKey) ?? false;
      
      if (!isAuthenticated) {
        return const AuthState.unauthenticated();
      }

      final userJson = prefs.getString(_userKey);
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final expiresAtString = prefs.getString(_expiresAtKey);

      if (userJson == null || accessToken == null || refreshToken == null || expiresAtString == null) {
        return const AuthState.unauthenticated();
      }

      final userMap = json.decode(userJson) as Map<String, dynamic>;
      final user = UserModel.fromMap(userMap);
      final expiresAt = DateTime.parse(expiresAtString);

      return AuthState.authenticated(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
    } catch (e) {
      // If there's any error reading from storage, return unauthenticated state
      return const AuthState.unauthenticated();
    }
  }

  @override
  Future<void> saveAuthState(AuthState authState) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!authState.isAuthenticated) {
      await clearAuthState();
      return;
    }

    final userModel = UserModel.fromUser(authState.user!);
    
    await Future.wait([
      prefs.setString(_userKey, json.encode(userModel.toMap())),
      prefs.setString(_accessTokenKey, authState.accessToken!),
      prefs.setString(_refreshTokenKey, authState.refreshToken!),
      prefs.setString(_expiresAtKey, authState.expiresAt!.toIso8601String()),
      prefs.setBool(_isAuthenticatedKey, true),
    ]);
  }

  @override
  Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    
    await Future.wait([
      prefs.remove(_userKey),
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_expiresAtKey),
      prefs.setBool(_isAuthenticatedKey, false),
    ]);
  }
} 